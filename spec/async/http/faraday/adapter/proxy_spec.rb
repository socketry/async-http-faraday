# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021, by Samuel Williams.

require 'async/http/faraday'
require 'async/http/server'
require 'async/http/endpoint'

require 'async'

RSpec.describe Async::HTTP::Faraday::Adapter, if: ENV.key?('PROXY_URL') do
	include_context Async::RSpec::Reactor
	
	def get_response(url = endpoint.url, path = '/index', adapter_options: {})
		connection = Faraday.new(url, proxy: ENV['PROXY_URL']) do |faraday|
			faraday.response :logger
			faraday.adapter :async_http, **adapter_options
		end
		
		connection.get(path)
	end
	
	it "can get remote resource via proxy" do
		Sync do
			response = get_response('https://www.google.com', '/search?q=cats')
			
			expect(response).to be_success
		end
	end
end
