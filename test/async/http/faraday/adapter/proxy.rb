# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2025, by Samuel Williams.

require "async/http/faraday"

require "sus/fixtures/async/reactor_context"

PROXY_URL = ENV.key?("PROXY_URL")

if PROXY_URL
	describe Async::HTTP::Faraday::Adapter do
		include Sus::Fixtures::Async::ReactorContext
		
		def get_response(url = endpoint.url, path = "/index", adapter_options: {})
			connection = Faraday.new(url, proxy: PROXY_URL) do |builder|
				builder.response :logger
				builder.adapter :async_http, **adapter_options
			end
			
			connection.get(path)
		end
		
		it "can get remote resource via proxy" do
			response = get_response("https://www.google.com", "/search?q=cats")
			
			expect(response).to be(:success?)
		end
	end
end
