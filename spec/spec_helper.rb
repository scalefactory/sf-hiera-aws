$LOAD_PATH.unshift File.expand_path('../../lib/', __FILE__)

require 'simplecov'
SimpleCov.start

require 'hiera'
require 'hiera/backend/sf_hiera_aws_backend.rb'
require 'webmock/rspec'
require 'mocha'
require 'yaml'
require 'aws-sdk-resources'
def fake_metadata
    {
        'accountId'          => '111111111111',
        'instanceId'         => 'i-99999999',
        'billingProducts'    => nil,
        'instanceType'       => 't2.medium',
        'imageId'            => 'ami-cd7156ba',
        'pendingTime'        => '2015-11-05T14  => 17 => 46Z',
        'kernelId'           => nil,
        'ramdiskId'          => nil,
        'architecture'       => 'x86_64',
        'region'             => 'eu-west-1',
        'version'            => '2010-08-31',
        'availabilityZone'   => 'eu-west-1a',
        'privateIp'          => '172.17.16.15',
        'devpayProductCodes' => nil
    }
end

class String
    # Strip leading whitespace from each line that is the same as the
    # amount of whitespace on the first line of the string.
    # Leaves _additional_ indentation on later lines intact.
    # Used for heredoc trimming
    def unindent
        gsub /^#{self[/\A[ \t]*/]}/, ''
    end
end

# Disable web connections
WebMock.disable_net_connect!

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
    # rspec-expectations config goes here. You can use an alternate
    # assertion/expectation library such as wrong or the stdlib/minitest
    # assertions if you prefer.
    config.expect_with :rspec do |expectations|
        # This option will default to `true` in RSpec 4. It makes the `description`
        # and `failure_message` of custom matchers include text for helper methods
        # defined using `chain`, e.g.:
        #     be_bigger_than(2).and_smaller_than(4).description
        #     # => "be bigger than 2 and smaller than 4"
        # ...rather than:
        #     # => "be bigger than 2"
        expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    end

    # rspec-mocks config goes here. You can use an alternate test double
    # library (such as bogus or mocha) by changing the `mock_with` option here.
    config.mock_with :mocha
end
