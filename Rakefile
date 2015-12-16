require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rspec/core/rake_task'

namespace :test do
    RSpec::Core::RakeTask.new(:unit) do |t|
        t.pattern = 'spec/unit/*_test.rb'
        t.rspec_opts = '--color'
    end
end
