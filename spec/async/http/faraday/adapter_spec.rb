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
require 'async/http/response'
require 'async/http/server'
require 'async/http/url_endpoint'
require 'async/reactor'

RSpec.describe Async::HTTP::Faraday::Adapter do
	let(:endpoint) {
		Async::HTTP::Endpoint.parse('http://127.0.0.1:9294')
	}

	it "client can get resource" do
		app = ->(request) do
			Async::HTTP::Response[200, {}, ["Hello World"]]
		end

		server = Async::HTTP::Server.new(app, endpoint)
		
		Async::Reactor.run do |task|
			server_task = task.async do
				server.run
			end
			
			conn = Faraday.new(:url => endpoint.url) do |faraday|
				faraday.response :logger
				faraday.adapter :async_http
			end
			
			response = conn.get("/index")
			
			expect(response.body).to be == "Hello World"
			
			server_task.stop
		end
	end
end
