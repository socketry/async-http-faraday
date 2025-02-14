# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2018, by Andreas Garnaes.
# Copyright, 2019, by Denis Talakevich.
# Copyright, 2019-2020, by Igor Sidorov.
# Copyright, 2023, by Genki Takiuchi.
# Copyright, 2023, by Flavio Fernandes.
# Copyright, 2024, by Jacob Frautschi.
# Copyright, 2025, by Nikolaos Anastopoulos.

require "faraday"
require "faraday/adapter"

require "async/barrier"
require "kernel/sync"

require "async/http/client"
require "async/http/proxy"

require_relative "clients"

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
			
			# Implement the Faraday parallel manager interface, using Async.
			class ParallelManager
				# Create a new parallel manager.
				def initialize(options = {})
					@options = options
					@barrier = nil
				end
				
				# @deprecated Please update your Faraday version!
				def run
					if $VERBOSE
						warn "Please update your Faraday version!", uplevel: 2
					end
				end
				
				# Run the given block asynchronously, using the barrier if available.
				def async(&block)
					if @barrier
						@barrier.async(&block)
					else
						Sync(&block)
					end
				end
				
				# Execute the given block which can perform multiple concurrent requests, waiting for them all to complete.
				def execute(&block)
					Sync do
						@barrier = Async::Barrier.new
						
						yield
						
						@barrier.wait
					ensure
						@barrier&.stop
					end
				end
			end
			
			# An adapter that allows Faraday to use Async::HTTP as the underlying HTTP client.
			class Adapter < ::Faraday::Adapter
				self.supports_parallel = true
				
				# Create a new parallel manager, which is used to handle multiple concurrent requests.
				def self.setup_parallel_manager(**options)
					ParallelManager.new(options)
				end
				
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
				def initialize(...)
					super
					
					@timeout = @connection_options.delete(:timeout)
					@read_timeout = @connection_options.delete(:read_timeout)
					
					if clients = @connection_options.delete(:clients)
						@clients = clients.call(**@connection_options, &@config_block)
					else
						@clients = PerThreadPersistentClients.new(**@connection_options, &@config_block)
					end
				end
				
				# @attribute [Numeric | Nil] The maximum time to send a request and wait for a response.
				attr :timeout
				
				# @attribute [Numeric | Nil] The maximum time to wait for an individual IO operation.
				attr :read_timeout
				
				# Close all clients.
				def close
					# The order of operations here is to avoid a race condition between iterating over clients (#close may yield) and creating new clients.
					@clients.close
				end
				
				# Make a request using the adapter.
				#
				# @parameter env [Faraday::Env] The environment to make the request in.
				# @raises [Faraday::TimeoutError] If the request times out.
				# @raises [Faraday::SSLError] If there is an SSL error.
				# @raises [Faraday::ConnectionFailed] If there is a connection error.
				def call(env)
					super
					
					# For compatibility with the default adapter:
					env.url.path = "/" if env.url.path.empty?
					
					if parallel_manager = env.parallel_manager
						parallel_manager.async do
							perform_request(env)
							env.response.finish(env)
						end
					else
						perform_request(env)
					end
					
					@app.call(env)
				end
				
				private
				
				def perform_request(env)
					with_client(env) do |endpoint, client|
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
						
						with_timeout(env.request.timeout || @timeout) do
							if env.stream_response?
								response = env.stream_response do |&on_data|
									response = client.call(request)
									
									save_response(env, response.status, nil, response.headers, finished: false)
									
									response.each do |chunk|
										on_data.call(chunk)
									end
									
									response
								end
							else
								response = client.call(request)
							end
							
							save_response(env, response.status, encoded_body(response), response.headers)
						end
					end
					
					return @app.call(env)
				rescue Errno::ETIMEDOUT, Async::TimeoutError => error
					raise ::Faraday::TimeoutError, error
				rescue OpenSSL::SSL::SSLError => error
					raise ::Faraday::SSLError, error
				rescue *CONNECTION_EXCEPTIONS => error
					raise ::Faraday::ConnectionFailed, error
				end
				
				def with_client(env)
					Sync do
						endpoint = Endpoint.new(env.url, timeout: @read_timeout)
						
						if proxy = env.request.proxy
							proxy_endpoint = Endpoint.new(proxy.uri)
							
							@clients.with_proxied_client(proxy_endpoint, endpoint) do |client|
								yield endpoint, client
							end
						else
							@clients.with_client(endpoint) do |client|
								yield endpoint, client
							end
						end
					end
				end
				
				def with_timeout(timeout = @timeout, task: Async::Task.current)
					if timeout
						task.with_timeout(timeout, ::Faraday::TimeoutError) do
							yield
						end
					else
						yield
					end
				end
				
				def encoded_body(response)
					body = response.read
					return "" if body.nil?
					content_type = response.headers["content-type"]
					return body unless content_type
					params = extract_type_parameters(content_type)
					if charset = params["charset"]
						body = body.dup if body.frozen?
						body.force_encoding(charset)
					end
					body
				rescue ArgumentError
					nil
				end
				
				def extract_type_parameters(content_type)
					result = {}
					list = content_type.split(";")
					list.shift
					list.each do |param|
						key, value = *param.split("=", 2)
						result[key.strip] = value.strip
					end
					result
				end
			end
		end
	end
end
