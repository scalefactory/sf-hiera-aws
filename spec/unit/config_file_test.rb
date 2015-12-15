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

            describe '#aws_config' do

               it 'should read a single config file' do

                   backend = Hiera::Backend::Sf_hiera_aws_backend.new

                   # Override config file path
                   backend.expects(:config_file_name).returns(
                        File.expand_path('../configs/simple_file.yaml', __FILE__)
                   )

                   expect(backend.aws_config).to eq({
                       'aws_ec2_nodes' => {
                           'type'    => :ec2_instance, 
                           'filters' =>[
                               { 
                                    'name'   => 'tag:aws:autoscaling:groupName', 
                                    'values' => ['euwest1-live-search']
                               }
                           ]
                       }
                   })

               end

               it 'should read a config directory, merging keys' do

                   backend = Hiera::Backend::Sf_hiera_aws_backend.new

                   # Override config file path
                   backend.expects(:config_file_name).returns(
                        File.expand_path('../configs/simple_file.yaml', __FILE__)
                   )
                   backend.expects(:config_directory_name).returns(
                        File.expand_path('../configs/directory', __FILE__)
                   )

                   expect(backend.aws_config).to eq({
                       'aws_ec2_nodes' => {
                           'type'    => :ec2_instance, 
                           'filters' =>[
                               { 
                                    'name'   => 'tag:aws:autoscaling:groupName', 
                                    'values' => ['euwest1-live-search']
                               }
                           ]
                       },
                       'aws_ec2_mongo_nodes' => {
                           'type'    => :ec2_instance, 
                           'filters' =>[
                               { 
                                    'name'   => 'tag:aws:autoscaling:groupName', 
                                    'values' => ['euwest1-live-mongo']
                               }
                           ]
                       },
                       'aws_ec2_ssh_nodes' => {
                           'type'    => :ec2_instance, 
                           'filters' =>[
                               { 
                                    'name'   => 'tag:aws:autoscaling:groupName', 
                                    'values' => ['euwest1-live-ssh']
                               }
                           ]
                       },

                   })

               end


            end
        end
    end
end
