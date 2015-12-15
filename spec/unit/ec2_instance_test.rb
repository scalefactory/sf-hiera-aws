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

                @instance_stub = { reservations: [ {
                    instances: [
                        {
                            instance_id:        'i-xxxxxxxx',
                            private_ip_address: '10.10.10.10',
                            private_dns_name:   'ip-10-10-10-10.eu-west-1.compute.internal',
                        },
                        {
                            instance_id:        'i-xxxxxxxy',
                            private_ip_address: '10.10.10.11',
                            private_dns_name:   'ip-10-10-10-11.eu-west-1.compute.internal',
                        }
                    ]
                } ] }

            end

            describe '#lookup' do

                it 'should perform RDS instance lookups matching a filter and return a list of hashes' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_ec2_nodes:
                      type: :ec2_instance
                      filters:
                        - name:   tag:aws:autoscaling:groupName
                          values: [ euwest1-live-search" ]
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    ec2 = Aws::EC2::Client.new()
                    ec2.stub_responses(:describe_instances, @instance_stub)
                    backend.expects(:get_ec2_client).returns(ec2)

                    expect(backend.lookup('aws_ec2_nodes', nil, nil, nil)).to eq([
                        {
                            'instance_id'        => 'i-xxxxxxxx',
                            'private_ip_address' => '10.10.10.10',
                            'private_dns_name'   => 'ip-10-10-10-10.eu-west-1.compute.internal',
                        },
                        {
                            'instance_id'        => 'i-xxxxxxxy',
                            'private_ip_address' => '10.10.10.11',
                            'private_dns_name'   => 'ip-10-10-10-11.eu-west-1.compute.internal',
                        }

                    ])
                end

                it 'should return only the hash elements requested' do

                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_ec2_nodes:
                      type: :ec2_instance
                      filters:
                        - name:   tag:aws:autoscaling:groupName
                          values: [ euwest1-live-search" ]
                      return:
                        - :instance_id
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    ec2 = Aws::EC2::Client.new()
                    ec2.stub_responses(:describe_instances, @instance_stub)
                    backend.expects(:get_ec2_client).returns(ec2)

                    expect(backend.lookup('aws_ec2_nodes', nil, nil, nil)).to eq([
                        { 'instance_id'        => 'i-xxxxxxxx', },
                        { 'instance_id'        => 'i-xxxxxxxy', }
                    ])

                end

            end
        end
    end
end
