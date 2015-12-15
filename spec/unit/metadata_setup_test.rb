require 'spec_helper'

class Hiera
    module Backend
        describe Sf_hiera_aws_backend do
            before do
                Hiera.stubs(:debug)
                Hiera.stubs(:warn)
            end

            it 'should read instance metadata correctly' do
                stub_request(:get, 'http://169.254.169.254/latest/dynamic/instance-identity/document').to_return(body: fake_metadata.to_json)

                backend = Hiera::Backend::Sf_hiera_aws_backend.new
                expect(backend.instance_eval { @instance_identity['region'] }).to eq 'eu-west-1'
            end

            it 'should cope with Net::OpenTimeout from the metadata server' do
                stub_request(:get, 'http://169.254.169.254/latest/dynamic/instance-identity/document').to_raise(Errno::EHOSTUNREACH)

                backend = Hiera::Backend::Sf_hiera_aws_backend.new
            end

            it 'should cope with Net::OpenTimeout from the metadata server' do
                stub_request(:get, 'http://169.254.169.254/latest/dynamic/instance-identity/document').to_raise(Net::OpenTimeout)

                backend = Hiera::Backend::Sf_hiera_aws_backend.new
            end

            it 'should cope with Net::OpenTimeout from the metadata server' do
                stub_request(:get, 'http://169.254.169.254/latest/dynamic/instance-identity/document').to_timeout

                backend = Hiera::Backend::Sf_hiera_aws_backend.new
            end
        end
    end
end
