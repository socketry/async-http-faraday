
require_relative "lib/async/http/faraday/version"

Gem::Specification.new do |spec|
	spec.name = "async-http-faraday"
	spec.version = Async::HTTP::Faraday::VERSION
	
	spec.summary = "Provides an adaptor between async-http and faraday."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/async-http"
	
	spec.files = Dir.glob('{examples,lib}/**/*', File::FNM_DOTMATCH, base: __dir__)
	
	spec.add_dependency "async-http", "~> 0.42"
	spec.add_dependency "faraday"
	
	spec.add_development_dependency "async-rspec", "~> 1.2"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "rspec", "~> 3.6"
end
