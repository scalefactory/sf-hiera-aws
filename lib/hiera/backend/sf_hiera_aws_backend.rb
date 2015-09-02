class Hiera

    module Backend

        class Sf_hiera_aws_backend

            public

            def initialize
                require 'aws-sdk-resources'
                Hiera.debug('Hiera AWS SDK backend started')
            end

            def lookup (key, scope, order_override, resolution_type)

                config = recursive_interpolate_config(aws_config, scope)

                Hiera.debug("Looking up '#{key} in AWS SDK backend")

                if ! config.key? key
                    return nil
                end

                Hiera.debug("Config: #{config[key].inspect}")
                type = config[key]['type']

                if self.methods.include? "type_#{type}".to_sym

                    begin
                        answer = self.send("type_#{type}".to_sym, config[key])
                        Hiera.debug( answer )
                        return answer
                    rescue Aws::Errors::MissingRegionError, Aws::Errors::MissingCredentialsError
                        Hiera.warn("No IAM role or ENV based AWS config - skipping")
                        return nil
                    end

                end

                Hiera.debug("Type of AWS SDK lookup '#{type}' invalid")
                return nil

            end

            def aws_config

                require 'yaml'

                default_config_path = "/etc/puppet/sf_hiera_aws.yaml"

                if ! Config[:aws_sdk].nil?
                    config_file = Config[:aws_sdk][:config_file] || default_config_path
                else
                    config_file = default_config_path
                end

                if File.exist?(config_file)
                    config = YAML::load_file(config_file)
                else
                    Hiera.warn("No config file #{config_file} found")
                    config = {}
                end

                config

            end

            def recursive_interpolate_config(h,scope)
                case h
                when Hash
                    Hash[
                    h.map do |k, v|
                        [ Backend.parse_answer(k, scope), recursive_interpolate_config(v,scope) ]
                    end
                    ]
                when Enumerable
                    h.map { |v| recursive_interpolate_config(v,scope) }
                when String
                    Backend.parse_answer(h,scope)
                else
                    h
                end
            end

            def type_ec2_instance(options)

                options = {
                    'return'  => [
                        :instance_id,
                        :private_ip_address,
                        :private_dns_name,
                    ]
                }.merge(options)

                ec2 = Aws::EC2::Resource.new()

                if options.key? 'filters'
                    instances = ec2.instances( filters: options['filters'] ) || []
                else
                    instances = ec2.instances() || []
                end

                instances.collect do |i|
                    Hash[ options['return'].map { |f|
                        [f.to_s, i.methods.include?(f) ? i.send(f) : nil ]
                    } ]
                end

            end

            def type_rds_db_instance(options)

                rds = Aws::RDS::Client.new()

                if options.key? 'db_instance_identifier'
                    instances = rds.describe_db_instances(
                        db_instance_identifier: options['db_instance_identifier']
                    ).db_instances
                else
                    instances = rds.describe_db_instances.db_instances
                end

                instances.collect do |i|
                    {
                        'db_instance_identifier' => i.db_instance_identifier,
                        'endpoint_address'       => i.endpoint.address,
                        'endpoint_port'          => i.endpoint.port,
                    }
                end

            end

            def type_elasticache_cache_cluster(options)

                elasticache = Aws::ElastiCache::Client.new()

                if options.key? 'cache_cluster_id'
                    clusters = elasticache.describe_cache_clusters(
                        cache_cluster_id: options['cache_cluster_id'],
                        show_cache_node_info: true,
                    ).cache_clusters
                else
                    clusters = elasticache.describe_cache_clusters(
                        show_cache_node_info: true
                    ).cache_clusters
                end

                clusters.collect do |i|
                    {
                        'cache_cluster_id' => i.cache_cluster_id,
                        'cache_nodes'      => i.cache_nodes.collect do |n|
                            {
                                'cache_node_id'    => n.cache_node_id,
                                'endpoint_address' => n.endpoint.address,
                                'endpoint_port'    => n.endpoint.port,
                            }
                        end
                    }
                end
            end

        end

    end

end

