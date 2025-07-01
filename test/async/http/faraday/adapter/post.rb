# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "async/http/faraday"

require "sus/fixtures/async/http/server_context"

describe Async::HTTP::Faraday::Adapter do
	with "a local http server" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[200, {}, request.body]
			end
		end
		
		with "explicit content-length" do
			it "client can post resource" do
				adapter = Faraday.new(bound_url) do |builder|
					builder.adapter :async_http
				end
				
				# We test for this case, because Faraday used to add `content-length` header automatically, causing duplicate headers. The adapter explicitly handles this case now, extracting `content-length` from the request headers and passing it into the body wrapper.
				response = adapter.post("/index", "Hello World", {"content-type" => "text/plain", "content-length" => "11"})
				expect(response.body).to be == "Hello World"
			ensure
				adapter&.close
			end
		end
	end
end
