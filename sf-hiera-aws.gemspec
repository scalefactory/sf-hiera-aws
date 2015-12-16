# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
    spec.name          = 'sf-hiera-aws'
    spec.version       = '0.0.3'
    spec.authors       = ['Jon Topper']
    spec.email         = ['jon@scalefactory.com']

    spec.summary       = 'Hiera backend for querying AWS resources'
    spec.homepage      = 'https://github.com/scalefactory/sf-hiera-aws'
    spec.license       = 'MIT'

    spec.files         = `git ls-files -z`.split("\x0").reject { |f|
                             f.match(%r{^(test|spec|features)/})
                         }
    spec.bindir        = 'exe'
    spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ['lib']

    spec.add_development_dependency 'bundler', '~> 1.8'
    spec.add_development_dependency 'rake', '~> 10.0'
    spec.add_dependency 'aws-sdk-resources', '>=2.2.6'
end
