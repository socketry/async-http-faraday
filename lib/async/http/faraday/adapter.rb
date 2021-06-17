# frozen_string_literal: true

# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'faraday'
require 'faraday/adapter'
require 'kernel/sync'

require 'async/http/client'
require 'async/http/proxy'

require_relative 'agent'

module Async
	module HTTP
		module Faraday
			class Adapter < ::Faraday::Adapter
				CONNECTION_EXCEPTIONS = [
					Errno::EADDRNOTAVAIL,
					Errno::ECONNABORTED,
					Errno::ECONNREFUSED,
					Errno::ECONNRESET,
					Errno::EHOSTUNREACH,
					Errno::EINVAL,
					Errno::ENETUNREACH,
					Errno::EPIPE,
					IOError,
					SocketError
				].freeze
				
				def initialize(*arguments, timeout: nil, **options, &block)
					super(*arguments, **options)
					
					@timeout = timeout
					
					@clients = {}
					
					@options = options
				end
				
				def make_client(endpoint)
					Client.new(endpoint, **@connection_options)
				end
				
				def host_key(endpoint)
					url = endpoint.url.dup
					
					url.path = ""
					url.fragment = nil
					url.query = nil
					
					return url
				end
				
				def client_for(endpoint)
					key = host_key(endpoint)
					
					@clients.fetch(key) do
						@clients[key] = make_client(endpoint)
					end
				end
				
				def proxy_client_for(proxy_endpoint, endpoint)
					key = [host_key(proxy_endpoint), host_key(endpoint)]
					
					@clients.fetch(key) do
						client = client_for(proxy_endpoint)
						@clients[key] = client.proxied_client(endpoint)
					end
				end
				
				def close
					# The order of operations here is to avoid a race condition between iterating over clients (#close may yield) and creating new clients.
					clients = @clients.values
					
					@clients.clear
					
					clients.each(&:close)
				end
				
				def call(env)
					super
					
					Sync do
						endpoint = Endpoint.new(env.url)
						
						if proxy = env.request.proxy
							proxy_endpoint = Endpoint.new(proxy.uri)
							client = self.proxy_client_for(proxy_endpoint, endpoint)
						else
							client = self.client_for(endpoint)
						end
						
						if body = env.body
							body = Body::Buffered.wrap(body)
						end
						
						if headers = env.request_headers
							headers = ::Protocol::HTTP::Headers[headers]
						end
						
						method = env.method.upcase
						
						request = ::Protocol::HTTP::Request.new(endpoint.scheme, endpoint.authority, method, endpoint.path, nil, headers, body)
						
						with_timeout do
							response = client.call(request)
							
							save_response(env, response.status, response.read, response.headers)
						end
					end
					
					return @app.call(env)
				rescue Errno::ETIMEDOUT, Async::TimeoutError => e
					raise ::Faraday::TimeoutError, e
				rescue OpenSSL::SSL::SSLError => e
					raise ::Faraday::SSLError, e
				rescue *CONNECTION_EXCEPTIONS => e
					raise ::Faraday::ConnectionFailed, e
				end
				
				private
				
				def with_timeout(task: Async::Task.current)
					if @timeout
						task.with_timeout(@timeout, ::Faraday::TimeoutError) do
							yield
						end
					else
						yield
					end
				end
			end
		end
	end
end
