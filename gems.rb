# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

source "https://rubygems.org"

gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	gem "bake-releases"
	
	gem "utopia-project"
	gem "decode"
end

group :test do
	gem "sus"
	gem "covered"
	
	gem "rubocop"
	gem "rubocop-md"
	gem "rubocop-socketry"
	
	gem "bake-test"
	
	gem "faraday-multipart"
	
	gem "sus-fixtures-async"
	gem "sus-fixtures-async-http"
	
	gem "protocol-multipart"
	
	gem "openssl", "~> 4.0"
end
