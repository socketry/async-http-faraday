
require_relative 'lib/async/http/faraday/version'

Gem::Specification.new do |spec|
  spec.name          = "async-http-faraday"
  spec.version       = Async::HTTP::Faraday::VERSION
  spec.authors       = ["Samuel Williams"]
  spec.email         = ["samuel.williams@oriontransfer.co.nz"]
  spec.license       = 'MIT'

  spec.summary       = "Provides an adaptor between async-http and faraday."
  spec.homepage      = "https://github.com/socketry/async-http"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.add_dependency("async-http", "~> 0.42")
  spec.add_dependency("faraday")
  
  spec.add_development_dependency "async-rspec", "~> 1.2"
  
  spec.add_development_dependency "bake-bundler"
  
  spec.add_development_dependency "covered"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rspec", "~> 3.6"
end
