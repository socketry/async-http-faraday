# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/http/faraday/clients'

describe Async::HTTP::Faraday::PersistentClients do
	let(:clients) {subject.new}
	
	with "#make_client" do
		it "caches the client" do
			endpoint = Async::HTTP::Endpoint.parse('http://example.com')
			client = clients.make_client(endpoint)
			
			expect(clients.make_client(endpoint)).to be_equal(client)
		end
	end
	
	with "#with_client" do
		it "caches the client" do
			endpoint = Async::HTTP::Endpoint.parse('http://example.com')
			
			clients.with_client(endpoint) do |client|
				clients.with_client(endpoint) do |other|
					expect(other).to be_equal(client)
				end
			end
		end
	end
	
	with "#with_proxied_client" do
		it "caches the client" do
			endpoint = Async::HTTP::Endpoint.parse('http://example.com')
			proxy_endpoint = Async::HTTP::Endpoint.parse('http://proxy.example.com')
			
			clients.with_proxied_client(proxy_endpoint, endpoint) do |client|
				clients.with_proxied_client(proxy_endpoint, endpoint) do |other|
					expect(other).to be_equal(client)
				end
			end
		end
	end
end
