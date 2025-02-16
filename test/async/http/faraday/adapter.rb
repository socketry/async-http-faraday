# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2018, by Andreas Garnaes.
# Copyright, 2019, by Denis Talakevich.
# Copyright, 2019-2020, by Igor Sidorov.
# Copyright, 2023, by Genki Takiuchi.
# Copyright, 2024, by Jacob Frautschi.
# Copyright, 2025, by Nikolaos Anastopoulos.

require "async/http/faraday"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/async/http/server_context"

require "faraday"
require "faraday/multipart"

require "protocol/http/body/file"

describe Async::HTTP::Faraday::Adapter do
	def get_response(url = bound_url, path = "/index", adapter_options: {})
		connection = Faraday.new(url) do |builder|
			builder.adapter :async_http, **adapter_options
		end
		
		connection.get(path)
	ensure
		connection&.close
	end
	
	with "#timeout" do
		it "can set timeout" do
			connection = Faraday.new do |builder|
				builder.adapter :async_http, timeout: 0.05
			end
			
			adapter = connection.builder.app
			
			expect(adapter).to have_attributes(
				timeout: be == 0.05
			)
		end
	end
	
	with "#read_timeout" do
		it "can set read timeout" do
			connection = Faraday.new do |builder|
				builder.adapter :async_http, read_timeout: 0.05
			end
			
			adapter = connection.builder.app
			
			expect(adapter).to have_attributes(
				read_timeout: be == 0.05
			)
		end
	end
	
	with "a local http server" do
		include Sus::Fixtures::Async::ReactorContext
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		with "basic http server" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, {}, ["Hello World"]]
				end
			end
			
			it "client can get resource" do
				expect(get_response.body).to be == "Hello World"
			end
			
			it "can make several requests on several threads" do
				connection = Faraday.new(bound_url) do |builder|
					builder.adapter :async_http
				end
				
				threads = []
				
				10.times do
					threads << Thread.new do
						10.times do
							response = connection.get("/index")
							expect(response).to be(:success?)
						end
					end
				end
				
				threads.each(&:join)
			end
		end
		
		with "utf-8 response body" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, {"content-type" => "text/html; charset=utf-8"}, ["こんにちは世界"]]
				end
			end
			
			it "client can get responce with respect to content-type encoding" do
				body = get_response.body
				
				expect(body.encoding).to be == Encoding::UTF_8
				expect(body).to be == "こんにちは世界"
			end
		end
		
		with "a large response body" do
			let(:large_response_size) {65536}
			
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, {}, ["." * large_response_size]]
				end
			end
			
			it "properly handles chunked responses" do
				expect(get_response.body.bytesize).to be == large_response_size
			end
		end
		
		with "a no content response" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[204]
				end
			end
			
			it "properly handles no content responses" do
				expect(get_response.body).to be == ""
			end
		end
		
		with "a slow response" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					sleep(0.1)
					Protocol::HTTP::Response[200, {}, ["Hello World"]]
				end
			end
			
			it "client can get resource" do
				expect(get_response.body).to be == "Hello World"
			end
			
			it "raises an exception if request times out" do
				expect do
					get_response(adapter_options: {timeout: 0.05})
				end.to raise_exception(Faraday::TimeoutError)
			end
		end
		
		with "a post request" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, {}, [request.body.read]]
				end
			end
			
			it "can post data" do
				response = Faraday.new do |builder|
					builder.adapter :async_http
				end.post(bound_url, "Hello World")
				
				expect(response.body).to be == "Hello World"
			end
			
			it "can use a url-encoded body" do
				response = Faraday.new do |builder|
					builder.request :url_encoded
					builder.adapter :async_http
				end.post(bound_url, text: "Hello World")
				
				expect(response.body).to be == "text=Hello+World"
			end
			
			it "can use a ::Protocol::HTTP::Body::Readable body" do
				readable = ::Protocol::HTTP::Body::File.new(File.open(__FILE__, "r"), 0...128)
				
				response = Faraday.new do |builder|
					builder.adapter :async_http
				end.post(bound_url, readable)
				
				expect(response.body).to be == File.read(__FILE__, 128)
			end
		end
		
		with "a config block" do
			it "invokes the config block" do
				config_block_invoked = false
				
				adapter = Faraday.new do |builder|
					builder.adapter :async_http do |client|
						config_block_invoked = true; client
					end
				end
				
				adapter.get(bound_url)
				
				expect(config_block_invoked).to be == true
			end
		end
		
		with "a streaming response" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					body = ::Async::HTTP::Body::Writable.new
					
					Async do
						3.times do |i|
							body.write("chunk#{i}")
						end
					ensure
						body.close_write
					end
					
					Protocol::HTTP::Response[200, {}, body]
				end
			end
			
			it "can stream response" do
				client = Faraday.new do |builder|
					builder.adapter :async_http
				end
				
				streamed = []
				env = nil
				
				response = client.get(bound_url) do |request|
					request.options.on_data = proc do |chunk, size, block_env|
						streamed << [chunk, size]
						env ||= block_env
					end
				end
				
				expect(response.body).to be(:empty?)
				expect(streamed).to be == [["chunk0", 6], ["chunk1", 12], ["chunk2", 18]]
				expect(env).to be_a(Faraday::Env)
				expect(env).to have_attributes(status: be == 200)
			end
		end
	end
	
	with "a remote http server" do
		it "can get remote resource" do
			Sync do
				response = get_response("http://www.google.com", "/search?q=cats")
			
				expect(response).to be(:success?)
			end
		end
		
		it "works without top level reactor" do
			response = get_response("https://www.google.com", "/search?q=ruby")
			
			expect(response).to be(:success?)
		end
		
		it "works without initial url and trailing slash (compatiblisity to the original behaviour)" do
			response = Faraday.new do |builder|
				builder.adapter :async_http
			end.get "https://www.google.com"
			
			expect(response).to be(:success?)
		end
		
		it "can use a multi-part post body" do
			connection = Faraday.new do |builder|
				builder.request :multipart
				builder.adapter :async_http
			end
			
			response = connection.post("https://httpbin.org/post") do |request|
				request.body = {"myfile" => Faraday::Multipart::FilePart.new(StringIO.new("file content"), "text/plain", "file.txt")}
			end
			
			body = JSON.parse(response.body)
			expect(body["files"]["myfile"]).to be == "file content"
		end
	end
	
	with "no server" do
		it "wraps underlying exceptions into Faraday analogs" do
			expect do
				get_response("http://localhost:1", "/index")
			end.to raise_exception(Faraday::ConnectionFailed)
		end
	end
end
