# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2021, by Samuel Williams.
# Copyright, 2018, by Andreas Garnaes.
# Copyright, 2019, by Denis Talakevich.
# Copyright, 2019-2020, by Igor Sidorov.
# Copyright, 2023, by Genki Takiuchi.
# Copyright, 2023, by Flavio Fernandes.

require 'faraday'
require 'faraday/adapter'
require 'kernel/sync'

require 'async/http/client'
require 'async/http/proxy'

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
						
						method = env.method.to_s.upcase
						
						request = ::Protocol::HTTP::Request.new(endpoint.scheme, endpoint.authority, method, endpoint.path, nil, headers, body)
						
						with_timeout do
							response = client.call(request)
							
							save_response(env, response.status, encoded_body(response), response.headers)
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
				
				def encoded_body(response)
					body = response.read
					return body if body.nil?
					content_type = response.headers['content-type']
					return body unless content_type
					params = extract_type_parameters(content_type)
					if charset = params['charset']
						body = body.dup if body.frozen?
						body.force_encoding(charset)
					end
					body
				rescue ArgumentError
					nil
				end
				
				def extract_type_parameters(content_type)
					result = {}
					list = content_type.split(';')
					list.shift
					list.each do |param|
						key, value = *param.split('=', 2)
						result[key.strip] = value.strip
					end
					result
				end
			end
		end
	end
end
