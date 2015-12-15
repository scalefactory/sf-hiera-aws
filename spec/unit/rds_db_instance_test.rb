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
            end

            describe '#lookup' do

                it 'should perform RDS instance lookups of a single instance and return a list of hashes' do
                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_rds_instance:
                      type: :rds_db_instance
                      db_instance_identifier: "euwest1-mgmt-db"
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    rds = Aws::RDS::Client.new
                    rds.stub_responses(:describe_db_instances, db_instances: [
                        db_instance_identifier: 'euwest1-mgmt-db',
                        endpoint: {
                            address: 'euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com',
                            port: 3306
                        },
                        preferred_backup_window: '04:13-04:43'
                    ])

                    backend.expects(:get_rds_client).returns(rds)

                    expect(backend.lookup('aws_rds_instance', nil, nil, nil)).to eq([{
                        'db_instance_identifier' => 'euwest1-mgmt-db',
                        'endpoint_address'       => 'euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com',
                        'endpoint_port'          => 3306
                    }])
                end

                it 'should perform RDS instance lookups of a single instance and return a hostname' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_rds_instance:
                      type: :rds_db_instance
                      db_instance_identifier: "euwest1-mgmt-db"
                      return: :hostname
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    rds = Aws::RDS::Client.new
                    rds.stub_responses(:describe_db_instances, db_instances: [
                        db_instance_identifier: 'euwest1-mgmt-db',
                        endpoint: {
                            address: 'euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com',
                            port: 3306
                        },
                        preferred_backup_window: '04:13-04:43'
                    ])

                    backend.expects(:get_rds_client).returns(rds)

                    expect(backend.lookup('aws_rds_instance', nil, nil, nil)).to eq('euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com')
                end

                it 'should perform RDS instance lookups of a single instance and return a hostname and port' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_rds_instance:
                      type: :rds_db_instance
                      db_instance_identifier: "euwest1-mgmt-db"
                      return: :hostname_and_port
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    rds = Aws::RDS::Client.new
                    rds.stub_responses(:describe_db_instances, db_instances: [
                        db_instance_identifier: 'euwest1-mgmt-db',
                        endpoint: {
                            address: 'euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com',
                            port: 3306
                        },
                        preferred_backup_window: '04:13-04:43'
                    ])

                    backend.expects(:get_rds_client).returns(rds)

                    expect(backend.lookup('aws_rds_instance', nil, nil, nil)).to eq('euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com:3306')
                end

                it 'should return nil if an invalid return type is specified' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_rds_instance:
                      type: :rds_db_instance
                      db_instance_identifier: "euwest1-mgmt-db"
                      return: :of_the_mack
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    rds = Aws::RDS::Client.new
                    rds.stub_responses(:describe_db_instances, db_instances: [
                        db_instance_identifier: 'euwest1-mgmt-db',
                        endpoint: {
                            address: 'euwest1-test-db.xxxxxxxxxxxx.eu-west-1.rds.amazonaws.com',
                            port: 3306
                        },
                        preferred_backup_window: '04:13-04:43'
                    ])

                    backend.expects(:get_rds_client).returns(rds)

                    expect(backend.lookup('aws_rds_instance', nil, nil, nil)).to eq(nil)
                end


            end

        end
    end
end
