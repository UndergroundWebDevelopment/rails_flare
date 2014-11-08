# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails_flare/version'

Gem::Specification.new do |spec|
  spec.name          = "rails_flare"
  spec.version       = RailsFlare::VERSION
  spec.authors       = ["Alex Willemsma"]
  spec.email         = ["alex@undergroundwebdevelopment.com"]
  spec.summary       = %q{Rails Flare provides a rails template for creating single page apps, especially with EmberJS.}
  spec.description   = nil
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 4.2.0.beta1"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
