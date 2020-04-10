# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async/http/faraday'
require 'async/http/server'
require 'async/http/endpoint'

require 'async'

RSpec.describe Async::HTTP::Faraday::Adapter do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {
		Async::HTTP::Endpoint.parse('http://127.0.0.1:9294')
	}
	
	def run_server(response = Protocol::HTTP::Response[204], response_delay: nil)
		Async do |task|
			begin
				server_task = task.async do
					app = Proc.new do
						if response_delay
							task.sleep(response_delay)
						end
						
						response
					end
					
					Async::HTTP::Server.new(app, endpoint).run
				end
				
				yield
			ensure
				server_task.stop
			end
		end.wait
	end
	
	def get_response(url = endpoint.url, path = '/index', adapter_options: {})
		connection = Faraday.new(url: url) do |faraday|
			faraday.response :logger
			faraday.adapter :async_http, adapter_options
		end
		
		connection.get(path)
	
	ensure
		connection&.close
	end
	
	it "client can get resource" do
		run_server(Protocol::HTTP::Response[200, {}, ['Hello World']]) do
			expect(get_response.body).to eq 'Hello World'
		end
	end
	
	it "works without top level reactor" do
		response = get_response("https://www.google.com", "/search?q=ruby")
		
		expect(response).to be_success
	end
	
	it "can get remote resource" do
		Async do
			response = get_response('http://www.google.com', '/search?q=cats')
			
			expect(response).to be_success
		end
	end
	
	it 'properly handles chunked responses' do
		large_response_size = 65536
		
		run_server(Protocol::HTTP::Response[200, {}, ['.' * large_response_size]]) do
			expect(get_response.body.size).to eq large_response_size
		end
	end
	
	it 'properly handles no content responses' do
		run_server(Protocol::HTTP::Response[204]) do
			expect(get_response.body).to be_nil
		end
	end
	
	it 'closes connection automatically if persistent option is set to false' do
		run_server do
			expect do
				get_response(adapter_options: { persistent: false })
			end.not_to raise_error
		end
	end
	
	it 'raises an exception if request times out' do
		delay = 0.1
		
		run_server(response_delay: delay) do
			expect do
				get_response(adapter_options: {timeout: delay / 2})
			end.to raise_error(Faraday::TimeoutError)
			
			expect do
				get_response(adapter_options: {timeout: delay * 2})
			end.not_to raise_error
		end
	end
	
	it 'wraps underlying exceptions into Faraday analogs' do
		expect { get_response(endpoint.url, '/index') }.to raise_error(Faraday::ConnectionFailed)
	end
end
