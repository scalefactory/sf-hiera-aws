require 'spec_helper'

class Hiera
    module Backend
        describe Sf_hiera_aws_backend do
            before do
                Hiera.stubs(:debug)
                Hiera.stubs(:warn)

                stub_request(:get, 'http://169.254.169.254/latest/dynamic/instance-identity/document').to_return(body: fake_metadata.to_json)

                Aws.config.update(stub_responses: true)

                class Config
                    @config = {}
                    class << self
                        def [](key)
                            @config[key]
                        end
                    end
                end

                @cache_clusters_stub = {
                    cache_clusters: [
                        {
                            cache_cluster_id: 'euwest1-test-redis',
                            cache_node_type:  'cache.t2.micro',
                            engine:           'redis',
                            num_cache_nodes:  1,
                            cache_nodes: [
                                {
                                    cache_node_id: '0001',
                                    endpoint: {
                                        address: 'euwest1-test-redis.xxxxxx.0001.euw1.cache.amazonaws.com',
                                        port: 6379,
                                    }
                                }
                            ]
                        },
                        {
                            cache_cluster_id: 'euwest1-test-redisr',
                            cache_node_type:  'cache.t2.micro',
                            engine:           'redis',
                            num_cache_nodes:  1,
                            cache_nodes: [
                                {
                                    cache_node_id: '0001',
                                    endpoint: {
                                        address: 'euwest1-test-redisr.xxxxxx.0001.euw1.cache.amazonaws.com',
                                        port: 6379,
                                    }
                                }
                            ]
                        }

                ] }
            end

            describe '#lookup' do

                it 'should perform elasticache lookups by id' do
                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_redis_cluster:
                      type:             :elasticache_cache_cluster
                      cache_cluster_id: "euwest1-test-redis"
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    elasticache = Aws::ElastiCache::Client.new()
                    cache_clusters_stub_single = @cache_clusters_stub.clone
                    cache_clusters_stub_single[:cache_clusters].pop
                    elasticache.stub_responses(:describe_cache_clusters, cache_clusters_stub_single)
                    backend.expects(:get_elasticache_client).returns(elasticache)

                    expect(backend.lookup('aws_redis_cluster', nil, nil, nil)).to eq([
                        {
                            'cache_cluster_id' => 'euwest1-test-redis',
                            'cache_nodes'      => [
                                {
                                    'cache_node_id'    => '0001',
                                    'endpoint_address' => 'euwest1-test-redis.xxxxxx.0001.euw1.cache.amazonaws.com',
                                    'endpoint_port'    => 6379
                                }
                            ]
                        }
                    ])
                end

                it 'should return a list of hostnames' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_redis_cluster:
                      type:             :elasticache_cache_cluster
                      cache_cluster_id: "euwest1-test-redis"
                      return:           :hostname
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    elasticache = Aws::ElastiCache::Client.new()
                    elasticache.stub_responses(:describe_cache_clusters, @cache_clusters_stub)
                    backend.expects(:get_elasticache_client).returns(elasticache)

                    expect(backend.lookup('aws_redis_cluster', nil, nil, nil)).to eq([
                        'euwest1-test-redis.xxxxxx.0001.euw1.cache.amazonaws.com',
                        'euwest1-test-redisr.xxxxxx.0001.euw1.cache.amazonaws.com'
                    ])
                end

                it 'should return a list of hostname:port strings' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_redis_cluster:
                      type:             :elasticache_cache_cluster
                      cache_cluster_id: "euwest1-test-redis"
                      return:           :hostname_and_port
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    elasticache = Aws::ElastiCache::Client.new()
                    elasticache.stub_responses(:describe_cache_clusters, @cache_clusters_stub)
                    backend.expects(:get_elasticache_client).returns(elasticache)

                    expect(backend.lookup('aws_redis_cluster', nil, nil, nil)).to eq([
                        'euwest1-test-redis.xxxxxx.0001.euw1.cache.amazonaws.com:6379',
                        'euwest1-test-redisr.xxxxxx.0001.euw1.cache.amazonaws.com:6379'
                    ])
                end


            end
        end
    end
end
