# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "async/http/faraday"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/async/http/server_context"

describe Async::HTTP::Faraday::Adapter do
	with "a local http server" do
		include Sus::Fixtures::Async::ReactorContext
		include Sus::Fixtures::Async::HTTP::ServerContext
		

		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[200, {}, ["Hello World"]]
			end
		end
		
		it "client can get resource" do
			adapter = Faraday.new(bound_url) do |builder|
				builder.adapter :async_http
			end
			
			response1 = response2 = response3 = nil
			
			adapter.in_parallel do
				response1 = adapter.get("/index")
				response2 = adapter.get("/index")
				response3 = adapter.get("/index")
			end
			
			expect(response1.body).to be == "Hello World"
			expect(response2.body).to be == "Hello World"
			expect(response3.body).to be == "Hello World"
		ensure
			adapter&.close
		end
	end
end
