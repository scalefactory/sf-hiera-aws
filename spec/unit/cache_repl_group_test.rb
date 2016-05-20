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

                @replication_groups_stub = {
                    replication_groups: [
                        {
                            node_groups: [
                                {
                                    node_group_members: [
                                        {
                                            current_role: 'primary',
                                            cache_node_id: '0001',
                                            read_endpoint: {
                                                port: 6379,
                                                address: 'euwest1-live-redis.xxxxxx.0001.euw1.cache.amazonaws.com'
                                            },
                                            cache_cluster_id: 'euwest1-live-redis'
                                        },
                                        {
                                            current_role: 'replica',
                                            cache_node_id: '0002',
                                            read_endpoint: {
                                                port: 6379,
                                                address: 'euwest1-live-redis2.xxxxxx.0001.euw1.cache.amazonaws.com'
                                            },
                                            cache_cluster_id: 'euwest1-live-redis2'
                                        }
                                    ],
                                    primary_endpoint: {
                                        port: 6379,
                                        address: 'euwest1-live-redis.xxxxxx.ng.0001.euw1.cache.amazonaws.com'
                                    }
                                }
                            ],
                            replication_group_id: 'euwest1-live-redis',
                        }
                    ]
                }
            end

            describe '#lookup' do

               it 'should return a list of hostnames' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_redis_replication_group:
                      type:                 :elasticache_replication_group
                      replication_group_id: "euwest1-live-redis"
                      return:               :primary_endpoint
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    elasticache = Aws::ElastiCache::Client.new()
                    elasticache.stub_responses(:describe_replication_groups, @replication_groups_stub)
                    backend.expects(:get_elasticache_client).returns(elasticache)

                    expect(backend.lookup('aws_redis_replication_group', nil, nil, nil)).to eq([
                        'euwest1-live-redis.xxxxxx.ng.0001.euw1.cache.amazonaws.com'
                    ])
                end

                it 'should return a list of hostname:port strings' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_redis_replication_group:
                      type:                 :elasticache_replication_group
                      replication_group_id: "euwest1-live-redis"
                      return:               :primary_endpoint_and_port
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    elasticache = Aws::ElastiCache::Client.new()
                    elasticache.stub_responses(:describe_replication_groups, @replication_groups_stub)
                    backend.expects(:get_elasticache_client).returns(elasticache)

                    expect(backend.lookup('aws_redis_replication_group', nil, nil, nil)).to eq([
                        'euwest1-live-redis.xxxxxx.ng.0001.euw1.cache.amazonaws.com:6379'
                    ])
                end

                it 'should perform elasticache replication group lookups by id' do
                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_redis_replication_group:
                      type:                 :elasticache_replication_group
                      replication_group_id: "euwest1-live-redis"
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    elasticache = Aws::ElastiCache::Client.new()
                    elasticache.stub_responses(:describe_replication_groups, @replication_groups_stub)
                    backend.expects(:get_elasticache_client).returns(elasticache)

                    expect(backend.lookup('aws_redis_replication_group', nil, nil, nil)).to eq([
                        {
                            'replication_group_id' => 'euwest1-live-redis',
                            'primary_endpoint_address'  => 'euwest1-live-redis.xxxxxx.ng.0001.euw1.cache.amazonaws.com',
                            'primary_endpoint_port'     => 6379,
                            'node_group_members'      => [
                                {
                                    'cache_node_id'             => '0001',
                                    'cache_cluster_id'        => 'euwest1-live-redis',
                                    'read_endpoint_address'     => 'euwest1-live-redis.xxxxxx.0001.euw1.cache.amazonaws.com',
                                    'read_endpoint_port'        => 6379,
                                    'current_role'              => 'primary',
                                },
                                {
                                    'cache_node_id'             => '0002',
                                    'cache_cluster_id'        => 'euwest1-live-redis2',
                                    'read_endpoint_address'     => 'euwest1-live-redis2.xxxxxx.0001.euw1.cache.amazonaws.com',
                                    'read_endpoint_port'        => 6379,
                                    'current_role'              => 'replica',
                                },
                            ]
                        }
                    ])
                end

            end
        end
    end
end
