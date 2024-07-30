# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2018, by Andreas Garnaes.
# Copyright, 2019, by Denis Talakevich.
# Copyright, 2019-2020, by Igor Sidorov.
# Copyright, 2023, by Genki Takiuchi.
# Copyright, 2023, by Flavio Fernandes.
# Copyright, 2024, by Jacob Frautschi.

require 'faraday'
require 'faraday/adapter'
require 'kernel/sync'

require 'async/http/client'
require 'async/http/proxy'

module Async
	module HTTP
		module Faraday
			# This is a simple wrapper around Faraday's body that allows it to be read in chunks.
			class BodyReadWrapper < ::Protocol::HTTP::Body::Readable
				# Create a new wrapper around the given body.
				#
				# The body must respond to `#read` and `#close` and is often an instance of `IO` or `Faraday::Multipart::CompositeReadIO`.
				#
				# @parameter body [Interface(:read)] The input body to wrap.
				# @parameter block_size [Integer] The size of the blocks to read from the body.
				def initialize(body, block_size: 4096)
					@body = body
					@block_size = block_size
				end
				
				# Close the body if possible.
				def close(error = nil)
					@body.close if @body.respond_to?(:close)
				ensure
					super
				end
				
				# Read from the body in chunks.
				def read
					@body.read(@block_size)
				end
			end
			
			# An adapter that allows Faraday to use Async::HTTP as the underlying HTTP client.
			class Adapter < ::Faraday::Adapter
				# The exceptions that are considered connection errors and result in a `Faraday::ConnectionFailed` exception.
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
				
				# Create a Farady compatible adapter.
				# 
				# @parameter timeout [Integer] The timeout for requests.
				# @parameter options [Hash] Additional options to pass to the underlying Async::HTTP::Client.
				def initialize(*arguments, timeout: nil, **options, &block)
					super(*arguments, **options)
					
					@timeout = timeout
					
					@clients = {}
					
					@options = options
				end
				
				# Make a new client for the given endpoint.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to create the client for.
				def make_client(endpoint)
					Client.new(endpoint, **@connection_options)
				end
				
				# Get the host key for the given endpoint.
				#
				# This is used to cache clients for the same host.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the host key for.
				def host_key(endpoint)
					url = endpoint.url.dup
					
					url.path = ""
					url.fragment = nil
					url.query = nil
					
					return url
				end
				
				# Get a client for the given endpoint. If a client already exists for the host, it will be reused.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				def client_for(endpoint)
					key = host_key(endpoint)
					
					@clients.fetch(key) do
						@clients[key] = make_client(endpoint)
					end
				end
				
				# Get a client for the given proxy endpoint and endpoint. If a client already exists for the host, it will be reused.
				#
				# @parameter proxy_endpoint [IO::Endpoint::Generic] The proxy endpoint to use.
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				def proxy_client_for(proxy_endpoint, endpoint)
					key = [host_key(proxy_endpoint), host_key(endpoint)]
					
					@clients.fetch(key) do
						client = client_for(proxy_endpoint)
						@clients[key] = client.proxied_client(endpoint)
					end
				end
				
				# Close all clients.
				def close
					# The order of operations here is to avoid a race condition between iterating over clients (#close may yield) and creating new clients.
					clients = @clients.values
					
					@clients.clear
					
					clients.each(&:close)
				end
				
				# Make a request using the adapter.
				#
				# @parameter env [Faraday::Env] The environment to make the request in.
				# @raises [Faraday::TimeoutError] If the request times out.
				# @raises [Faraday::SSLError] If there is an SSL error.
				# @raises [Faraday::ConnectionFailed] If there is a connection error.
				def call(env)
					super
					
					# for compatibility with the default adapter
					env.url.path = '/' if env.url.path.empty?
					
					Sync do
						endpoint = Endpoint.new(env.url)
						
						if proxy = env.request.proxy
							proxy_endpoint = Endpoint.new(proxy.uri)
							client = self.proxy_client_for(proxy_endpoint, endpoint)
						else
							client = self.client_for(endpoint)
						end
						
						if body = env.body
							# We need to ensure the body is wrapped in a Readable object so that it can be read in chunks:
							# Faraday's body only responds to `#read`.
							if body.is_a?(::Protocol::HTTP::Body::Readable)
								# Good to go
							elsif body.respond_to?(:read)
								body = BodyReadWrapper.new(body)
							else
								body = ::Protocol::HTTP::Body::Buffered.wrap(body)
							end
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
