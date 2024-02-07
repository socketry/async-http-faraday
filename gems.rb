# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

source 'https://rubygems.org'

gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
end

group :test do
	gem "bake-test"
	gem "bake-test-external"
	
	gem "faraday-multipart"
end

# Moved Development Dependencies
gem "async-rspec", "~> 1.2"
gem "covered"
gem "rspec", "~> 3.6"
