# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "async/http/faraday/clients"
require "async/http/middleware/location_redirector"

require "sus/fixtures/async/http/server_context"

require "socket"

class ConnectProxy
	def initialize
		@server = TCPServer.new("127.0.0.1", 0)
		@workers = []
		@thread = Thread.new do
			loop do
				client = @server.accept
				@workers << Thread.new{tunnel(client)}
			end
		rescue IOError, Errno::EBADF
			# The server was closed.
		end
	end
	
	def endpoint
		Async::HTTP::Endpoint.parse("http://127.0.0.1:#{@server.local_address.ip_port}")
	end
	
	def close
		@server.close
		@thread.join
		@workers.each(&:join)
	end
	
	private
	
	def tunnel(client)
		request = client.gets
		return unless request&.start_with?("CONNECT ")
		
		authority = request.split(" ", 3)[1]
		host, port = authority.split(":", 2)
		
		while (line = client.gets) && line != "\r\n"
		end
		
		upstream = TCPSocket.new(host, port)
		client.write("HTTP/1.1 200 Connection established\r\n\r\n")
		
		copy(client, upstream)
	ensure
		client&.close
		upstream&.close
	end
	
	def copy(client, upstream)
		pump = lambda do |input, output|
			Thread.new do
				IO.copy_stream(input, output)
			rescue IOError, SystemCallError
				# Either side of the tunnel was closed.
			ensure
				output.close_write rescue nil
			end
		end
		
		threads = [pump.call(client, upstream), pump.call(upstream, client)]
		
		threads.each(&:join)
	end
end

describe Async::HTTP::Faraday::PersistentClients do
	let(:clients) {subject.new}
	
	with "a block" do
		let(:clients) do
			subject.new do |client|
				Async::HTTP::Middleware::LocationRedirector.new(client)
			end
		end
		
		it "can wrap the client with middleware" do
			endpoint = Async::HTTP::Endpoint.parse("http://example.com")
			client = clients.make_client(endpoint)
			
			expect(client).to be_a(Async::HTTP::Middleware::LocationRedirector)
		end
	end
	
	with "#make_client" do
		it "caches the client" do
			endpoint = Async::HTTP::Endpoint.parse("http://example.com")
			client = clients.make_client(endpoint)
			
			expect(clients.make_client(endpoint)).to be_equal(client)
		end
	end
	
	with "#with_client" do
		it "caches the client" do
			endpoint = Async::HTTP::Endpoint.parse("http://example.com")
			
			clients.with_client(endpoint) do |client|
				clients.with_client(endpoint) do |other|
					expect(other).to be_equal(client)
				end
			end
		end
	end
	
	with "#with_proxied_client" do
		it "caches the client" do
			endpoint = Async::HTTP::Endpoint.parse("http://example.com")
			proxy_endpoint = Async::HTTP::Endpoint.parse("http://proxy.example.com")
			
			clients.with_proxied_client(proxy_endpoint, endpoint) do |client|
				clients.with_proxied_client(proxy_endpoint, endpoint) do |other|
					expect(other).to be_equal(client)
				end
			end
		end
	end
	
	with "#close" do
		it "closes all clients" do
			endpoint = Async::HTTP::Endpoint.parse("http://example.com")
			client = clients.make_client(endpoint)
			expect(client).to receive(:close)
			
			clients.close
		end
		
		with "a CONNECT proxy" do
			include Sus::Fixtures::Async::HTTP::ServerContext
			
			it "closes the tunnel before the proxy client" do
				proxy = ConnectProxy.new
				endpoint = Async::HTTP::Endpoint.parse(bound_url)
				closed = false
				
				clients.with_proxied_client(proxy.endpoint, endpoint) do |client|
					response = client.get("/")
					expect(response.read).to be == "Hello World!"
				end
				
				cached_clients = clients.instance_variable_get(:@clients).values
				
				Async::Task.current.with_timeout(1) do
					clients.close
					closed = true
				end
			ensure
				cached_clients&.reverse_each(&:close) unless closed
				proxy&.close
			end
		end
	end
end

describe Async::HTTP::Faraday::PerThreadPersistentClients do
	let(:clients) {subject.new}
	
	with "#close" do
		it "closes all clients" do
			endpoint = Async::HTTP::Endpoint.parse("http://example.com")
			closed = false
			
			clients.with_client(endpoint) do |client|
				expect(client).to receive(:close, &proc{closed = true})
			end
			
			expect(closed).to be == false
			clients.close
			expect(closed).to be == true
		end
	end
end
