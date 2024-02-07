# frozen_string_literal: true

require_relative "lib/async/http/faraday/version"

Gem::Specification.new do |spec|
	spec.name = "async-http-faraday"
	spec.version = Async::HTTP::Faraday::VERSION
	
	spec.summary = "Provides an adaptor between async-http and faraday."
	spec.authors = ["Samuel Williams", "Igor Sidorov", "Andreas Garnaes", "Genki Takiuchi", "Olle Jonsson", "Benoit Daloze", "Denis Talakevich", "Flavio Fernandes"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/async-http"
	
	spec.files = Dir.glob(['{examples,lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.0"
	
	spec.add_dependency "async-http", "~> 0.42"
	spec.add_dependency "faraday"
end
