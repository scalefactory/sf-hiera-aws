class Hiera
    module Backend
        class Sf_hiera_aws_backend
            private

            @instance_identity = nil

            def read_link_local_data
                require 'net/http'
                require 'json'

                begin
                    http = Net::HTTP.new('169.254.169.254', 80)
                    http.open_timeout = 1
                    http.read_timeout = 1
                    @instance_identity = JSON.parse(http.request(Net::HTTP::Get.new('/latest/dynamic/instance-identity/document')).body)
                rescue Errno::EHOSTUNREACH, Net::OpenTimeout, Timeout::Error
                    Hiera.warn('No link-local endpoint - can\'t calculate region')
                end
            end

            # Wrapped these in getters for dependency injection purposes
            def get_rds_client
                Aws::RDS::Client.new
            end

            def get_ec2_client
                Aws::EC2::Client.new
            end

            def get_elasticache_client
                Aws::ElastiCache::Client.new
            end

            public

            def initialize
                require 'aws-sdk-resources'

                read_link_local_data
                unless @instance_identity.nil?
                    Aws.config.update(region: @instance_identity['region'])
                end

                Hiera.debug('Hiera AWS SDK backend started')
            end

            def lookup(key, scope, _order_override, _resolution_type)
                config = recursive_interpolate_config(aws_config, scope)

                Hiera.debug("Looking up '#{key} in AWS SDK backend")

                return nil unless config.key? key

                Hiera.debug("Config: #{config[key].inspect}")
                type = config[key]['type']

                if methods.include? "type_#{type}".to_sym

                    begin
                        answer = send("type_#{type}".to_sym, config[key])
                        Hiera.debug(answer)
                        return answer
                    rescue Aws::Errors::MissingRegionError, Aws::Errors::MissingCredentialsError
                        Hiera.warn('No IAM role or ENV based AWS config - skipping')
                        return nil
                    end

                end

                Hiera.debug("Type of AWS SDK lookup '#{type}' invalid")
                nil
            end

            def config_file_name

                default_config_path = '/etc/puppet/sf_hiera_aws.yaml'

                if !Config[:aws_sdk].nil?
                    config_file = Config[:aws_sdk][:config_file] || default_config_path
                else
                    config_file = default_config_path
                end

                return config_file

            end

            def config_directory_name

                default_config_path = '/etc/puppet/sf_hiera_aws.d'

                if !Config[:aws_sdk].nil?
                    config_dir = Config[:aws_sdk][:config_directory] || default_config_path
                else
                    config_dir = default_config_path
                end

                return config_dir

            end


            def aws_config

                require 'yaml'

                config_file = config_file_name

                if File.exist?(config_file)
                    config = YAML.load_file(config_file)
                else
                    Hiera.warn("No config file #{config_file} found")
                    config = {}
                end

                # Merge configs from the config directory too

                config_directory = config_directory_name

                if File.directory?(config_directory)
                    Dir.entries(config_directory).sort.each do |p|
                        next if p == '.' or p == '..'
                        to_merge = YAML.load_file( File.join( config_directory, p ) )
                        config.merge! to_merge
                    end
                end

                config
            end

            def recursive_interpolate_config(h, scope)
                case h
                when Hash
                    Hash[
                    h.map do |k, v|
                        [Backend.parse_answer(k, scope), recursive_interpolate_config(v, scope)]
                    end
                    ]
                when Enumerable
                    h.map { |v| recursive_interpolate_config(v, scope) }
                when String
                    Backend.parse_answer(h, scope)
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

                ec2 = get_ec2_client

                instances = []

                if options.key? 'filters'

                    ec2.describe_instances(filters: options['filters']).reservations.each do |r|
                        r.instances.each do |i|
                            instances << i
                        end
                    end

                else

                    ec2.describe_instances().reservations.each do |r|
                        r.instances.each do |i|
                            instances << i
                        end
                    end

                end

                instances.collect do |i|
                    if options['return'].is_a?(Array)

                        # If the 'return' option is a list, we treat these
                        # as a list of desired hash keys, and return a hash
                        # containing only those keys from the API call
                        
                        Hash[options['return'].map do |f|
                            [f.to_s, i.key?(f) ? i[f] : nil]
                        end]

                    elsif options['return'].is_a?(Symbol)

                        # If the 'return' option is a symbol, we treat that
                        # as the one hash key we care about, and return a list
                        # of that.

                        i.key?(options['return']) ? i[options['return']] : nil

                    end
                end
            end

            def type_rds_db_instance(options)
                rds = get_rds_client

                if options.key? 'db_instance_identifier'
                    instances = rds.describe_db_instances(
                        db_instance_identifier: options['db_instance_identifier']
                    ).db_instances
                else
                    instances = rds.describe_db_instances.db_instances
                end

                if !options.key? 'return'

                    return instances.collect do |i|
                        {
                            'db_instance_identifier' => i.db_instance_identifier,
                            'endpoint_address'       => i.endpoint.address,
                            'endpoint_port'          => i.endpoint.port,
                        }
                    end

                end

                if options['return'] == :hostname

                    return instances.first.endpoint.address

                elsif options['return'] == :hostname_and_port

                    return [
                        instances.first.endpoint.address,
                        instances.first.endpoint.port,
                    ].join(':')

                else

                    Hiera.warn("No return handler for #{options['return']} in rds_db_instance")
                    return nil

                end



            end

            def type_elasticache_cache_cluster(options)
                elasticache = get_elasticache_client

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

                if !options.key? 'return'

                    return clusters.collect do |i|
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

                if options['return'] == :hostname

                    nodes = []

                    clusters.each do |c|
                        c.cache_nodes.each do |n|
                            nodes.push(n.endpoint.address)
                        end
                    end

                    return nodes

                elsif options['return'] == :hostname_and_port

                    nodes = []

                    clusters.each do |c|
                        c.cache_nodes.each do |n|
                            nodes.push( [ n.endpoint.address, n.endpoint.port ].join(':') )
                        end
                    end

                    return nodes

                end

            end

            def type_elasticache_replication_group(options)
                elasticache = get_elasticache_client

                if options.key? 'replication_group_id'
                    replgroups = elasticache.describe_replication_groups(
                        replication_group_id: options['replication_group_id'],
                    ).replication_groups
                else
                    replgroups = elasticache.describe_replication_groups.replication_groups
                end

                if !options.key? 'return'

                    return replgroups.collect do |rg|
                        {
                            'replication_group_id' => rg.replication_group_id,
                            'primary_endpoint_address' => rg.node_groups[0].primary_endpoint.address,
                            'primary_endpoint_port' => rg.node_groups[0].primary_endpoint.port,
                            'node_group_members' => rg.node_groups[0].node_group_members.collect do |ngm| 
                                {
                                    'cache_node_id' => ngm.cache_node_id,
                                    'cache_cluster_id' => ngm.cache_cluster_id,
                                    'read_endpoint_address' => ngm.read_endpoint.address,
                                    'read_endpoint_port' => ngm.read_endpoint.port,
                                    'current_role' => ngm.current_role,
                                }
                            end
                        }
                    end

                end

                if options['return'] == :primary_endpoint

                    primary_endpoints = []

                    replgroups.each do |rg|
                        primary_endpoints.push(rg.node_groups[0].primary_endpoint.address)
                    end

                    return primary_endpoints

                elsif options['return'] == :primary_endpoint_and_port

                    primary_endpoints = []

                    replgroups.each do |rg|
                        primary_endpoints.push( [ rg.node_groups[0].primary_endpoint.address, rg.node_groups[0].primary_endpoint.port ].join(':') )
                    end

                    return primary_endpoints

               end

            end
        end
    end
end
