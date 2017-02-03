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

                @asg_stub_small = {
                    auto_scaling_groups: [
                        {
                            auto_scaling_group_name: "euwest1-test-backend",
                            launch_configuration_name: "euwest1-test-backend_1484914261",
                            load_balancer_names: [],
                            min_size: 1,
                            max_size: 1,
                            desired_capacity: 1,
                            default_cooldown: 300,
                            availability_zones: ["eu-west-1b","eu-west-1c","eu-west-1a"],
                            health_check_type: "EC2",
                            health_check_grace_period: 120,
                            created_time: Time.now(),
                            instances: [
                                {
                                    instance_id: "i-123abc12",
                                    availability_zone: "eu-west-1c",
                                    lifecycle_state: "InService",
                                    health_status: "Healthy",
                                    launch_configuration_name: 'euwest1-test-backend_1484914261',
                                    protected_from_scale_in: false
                                }
                            ]
                        }
                    ]
                }
                @asg_stub_big = {
                    auto_scaling_groups: [
                        {
                            auto_scaling_group_name: "euwest1-test-api",
                            launch_configuration_name: "euwest1-test-api_14844234231",
                            load_balancer_names: ["euwest1-test-lb-api"],
                            min_size: 3,
                            max_size: 10,
                            desired_capacity: 3,
                            default_cooldown: 300,
                            availability_zones: ["eu-west-1b","eu-west-1c","eu-west-1a"],
                            health_check_type: "EC2",
                            health_check_grace_period: 120,
                            created_time: Time.now(),
                            instances: [
                                {
                                    instance_id: "i-123abc13",
                                    availability_zone: "eu-west-1a",
                                    lifecycle_state: "InService",
                                    health_status: "Healthy",
                                    launch_configuration_name: 'euwest1-test-api_14844234231',
                                    protected_from_scale_in: false
                                },
                                {
                                    instance_id: "i-123abc14",
                                    availability_zone: "eu-west-1a",
                                    lifecycle_state: "InService",
                                    health_status: "Healthy",
                                    launch_configuration_name: 'euwest1-test-api_14844234231',
                                    protected_from_scale_in: false
                                },
                                {
                                    instance_id: "i-123abc15",
                                    availability_zone: "eu-west-1a",
                                    lifecycle_state: "Pending",
                                    health_status: "Healthy",
                                    launch_configuration_name: 'euwest1-test-api_14844234231',
                                    protected_from_scale_in: false
                                }
                            ]
                        }
                    ]
                }

                @ec2_stub = { reservations: [ {
                    instances: [
                        {
                            instance_id:        'i-123abc13',
                            private_ip_address: '10.10.10.11',
                            private_dns_name:   'ip-10-10-10-11.eu-west-1.compute.internal',
                        },
                        {
                            instance_id:        'i-123abc14',
                            private_ip_address: '10.10.10.12',
                            private_dns_name:   'ip-10-10-10-12.eu-west-1.compute.internal',
                        }
                    ]
                } ] }
            end

            describe '#lookup' do

                it 'should perform asg lookup by name' do
                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_asg_group:
                      type:                     :autoscaling_group
                      auto_scaling_group_names: ["euwest1-test-backend"]
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    autoscaling = Aws::AutoScaling::Client.new()
                    asg_stub_single = @asg_stub_small.clone
                    autoscaling.stub_responses(:describe_auto_scaling_groups, asg_stub_single)
                    backend.expects(:get_autoscaling_client).returns(autoscaling)

                    expect(backend.lookup('aws_asg_group', nil, nil, nil)).to eq([
                        {
                            'auto_scaling_group_name' => "euwest1-test-backend",
                            'launch_configuration_name' => "euwest1-test-backend_1484914261",
                            'load_balancer_names' => [],
                            'instances' => [
                                {
                                    'instance_id' => "i-123abc12",
                                    'availability_zone' => "eu-west-1c",
                                    'lifecycle_state' => "InService",
                                    'health_status' => "Healthy",
                                    'launch_configuration_name' => 'euwest1-test-backend_1484914261',
                                    'protected_from_scale_in' => false
                                }
                            ]
                        }
                    ])
                end

                it 'should perform asg lookup by name and get ip addresses of InService nodes' do
                    config_yaml = YAML.load(<<-EOF.unindent)
                    ---
                    aws_asg_group:
                      type:                     :autoscaling_group
                      auto_scaling_group_names: ["euwest1-test-api"]
                      return:                   :instance_details_inservice_ip
                    EOF

                    backend = Hiera::Backend::Sf_hiera_aws_backend.new
                    backend.expects(:aws_config).returns(config_yaml)

                    autoscaling = Aws::AutoScaling::Client.new()
                    ec2 = Aws::EC2::Client.new()
                    
                    asg_stub = @asg_stub_big.clone
                    autoscaling.stub_responses(:describe_auto_scaling_groups, asg_stub)
                    backend.expects(:get_autoscaling_client).returns(autoscaling)

                    ec2_stub = @ec2_stub.clone
                    ec2.stub_responses(:describe_instances, ec2_stub)
                    backend.expects(:get_ec2_client).returns(ec2)

                    expect(backend.lookup('aws_asg_group', nil, nil, nil)).to eq([
                        {"private_ip_address"=>"10.10.10.11"},
                        {"private_ip_address"=>"10.10.10.12"}
                    ])
                end

            end
        end
    end
end
