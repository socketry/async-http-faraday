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
	let(:endpoint) {
		Async::HTTP::Endpoint.parse('http://127.0.0.1:9294')
	}

	def run_server(response)
		Async do |task|
			begin
				server_task = task.async do
					app = ->(_) { response }
					Async::HTTP::Server.new(app, endpoint).run
				end

				yield
			ensure
				server_task.stop
			end
		end.wait
	end

	def get_response(url, path)
		connection = Faraday.new(url: url) do |faraday|
			faraday.response :logger
			faraday.adapter :async_http
		end

		connection.get(path)
	end

	it "client can get resource" do
		run_server(Protocol::HTTP::Response[200, {}, ['Hello World']]) do
			response = get_response(endpoint.url, '/index')
		
			expect(response.body).to eq 'Hello World'
		end
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
			response = get_response(endpoint.url, '/index')

			expect(response.body.size).to eq large_response_size
		end
	end

	it 'properly handles no content responses' do
		run_server(Protocol::HTTP::Response[204]) do
			response = get_response(endpoint.url, '/index')

			expect(response.body).to be_nil
		end
	end
end
