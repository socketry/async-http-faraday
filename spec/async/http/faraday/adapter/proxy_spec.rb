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

RSpec.describe Async::HTTP::Faraday::Adapter, if: ENV.key?('PROXY_URL') do
	include_context Async::RSpec::Reactor
	
	def get_response(url = endpoint.url, path = '/index', adapter_options: {})
		connection = Faraday.new(url: url) do |faraday|
			faraday.response :logger
			faraday.adapter :async_http, **adapter_options
		end
		
		connection.get(path, proxy: ENV['PROXY_URL'])
	end
	
	it "can get remote resource via proxy" do
		Async do
			response = get_response('http://www.google.com', '/search?q=cats')
			
			expect(response).to be_success
		end
	end
end
