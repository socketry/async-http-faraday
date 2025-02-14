# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "faraday"
require "faraday/adapter"
require "kernel/sync"

require "async/http/client"
require "async/http/proxy"

module Async
	module HTTP
		module Faraday
			# An interface for creating and managing HTTP clients.
			class Clients
				# Create a new instance of the class.
				def self.call(...)
					new(...)
				end
				
				# Create a new interface for managing HTTP clients.
				#
				# @parameter options [Hash] The options to create the clients with.
				# @parameter block [Proc] An optional block to call with the client before it is used.
				def initialize(**options, &block)
					@options = options
					@block = block
				end
				
				# Close all clients.
				def close
				end
				
				# Make a new client for the given endpoint.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to create the client for.
				def make_client(endpoint)
					client = Client.new(endpoint, **@options)
					
					return @block&.call(client) || client
				end
				
				# Get a client for the given endpoint.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				# @yields {|client| ...} A client for the given endpoint.
				def with_client(endpoint)
					client = make_client(endpoint)
					
					yield client
				ensure
					client&.close
				end
				
				# Get a client for the given proxy endpoint and endpoint.
				#
				# @parameter proxy_endpoint [IO::Endpoint::Generic] The proxy endpoint to use.
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				# @yields {|client| ...} A client for the given endpoint.
				def with_proxied_client(proxy_endpoint, endpoint)
					client = make_client(proxy_endpoint)
					proxied_client = client.proxied_client(endpoint)
					
					yield proxied_client 
				ensure
					proxied_client&.close
					client&.close
				end
			end
			
			# An interface for creating and managing persistent HTTP clients.
			class PersistentClients < Clients
				# Create a new instance of the class.
				def initialize(...)
					super
					
					@clients = {}
				end
				
				# Close all clients.
				def close
					super
					
					clients = @clients.values
					@clients.clear
					
					clients.each(&:close)
				end
				
				# Lookup or create a client for the given endpoint.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to create the client for.
				def make_client(endpoint)
					key = host_key(endpoint)
					
					fetch(key) do
						super
					end
				end
				
				# Get a client for the given endpoint. If a client already exists for the host, it will be reused.
				#
				# @yields {|client| ...} A client for the given endpoint.
				def with_client(endpoint)
					yield make_client(endpoint)
				end
				
				# Get a client for the given proxy endpoint and endpoint. If a client already exists for the host, it will be reused.
				#
				# @parameter proxy_endpoint [IO::Endpoint::Generic] The proxy endpoint to use.
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				def with_proxied_client(proxy_endpoint, endpoint)
					key = [host_key(proxy_endpoint), host_key(endpoint)]
					
					proxied_client = fetch(key) do
						make_client(proxy_endpoint).proxied_client(endpoint)
					end
					
					yield proxied_client
				end
				
				private
				
				def fetch(key)
					@clients.fetch(key) do
						@clients[key] = yield
					end
				end
				
				def host_key(endpoint)
					url = endpoint.url.dup
					
					url.path = ""
					url.fragment = nil
					url.query = nil
					
					return url
				end
			end
			
			# An interface for creating and managing per-thread persistent HTTP clients.
			class PerThreadPersistentClients
				# Create a new instance of the class.
				#
				# @parameter options [Hash] The options to create the clients with.
				# @parameter block [Proc] An optional block to call with the client before it is used.
				def initialize(**options, &block)
					@options = options
					@block = block
					
					@key = :"#{self.class}_#{object_id}"
				end
				
				# Get a client for the given endpoint. If a client already exists for the host, it will be reused.
				#
				# The client instance will be will be cached per-thread.
				#
				# @yields {|client| ...} A client for the given endpoint.
				def with_client(endpoint, &block)
					clients.with_client(endpoint, &block)
				end
				
				# Get a client for the given proxy endpoint and endpoint. If a client already exists for the host, it will be reused.
				#
				# The client instance will be will be cached per-thread.
				#
				# @parameter proxy_endpoint [IO::Endpoint::Generic] The proxy endpoint to use.
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				def with_proxied_client(proxy_endpoint, endpoint, &block)
					clients.with_proxied_client(proxy_endpoint, endpoint, &block)
				end
				
				# Close all clients.
				#
				# This will close all clients associated with all threads.
				def close
					Thread.list.each do |thread|
						if clients = thread[@key]
							clients.close
							
							thread[@key] = nil
						end
					end
				end
				
				private
				
				def make_clients
					PersistentClients.new(**@options, &@block)
				end
				
				def clients
					thread = Thread.current
					
					return thread.thread_variable_get(@key) || thread.thread_variable_set(@key, make_clients)
				end
			end
		end
	end
end
