# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'float-formats/version'

Gem::Specification.new do |spec|
  spec.name          = "float-formats"
  spec.version       = Flt::Frmts::VERSION
  spec.authors       = ["Javier Goizueta"]
  spec.email         = ["jgoizueta@gmail.com"]
  spec.summary       = %q{Floating-Point Formats}
  spec.description   = %q{Floating-Point Formats}
  spec.homepage      = "https://github.com/jgoizueta/float-formats"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'flt', "~> 1.5"
  spec.add_dependency 'numerals', "~> 0.3"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.required_ruby_version = '>= 1.9.3'
end
