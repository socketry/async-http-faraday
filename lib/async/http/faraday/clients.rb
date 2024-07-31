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
			class Clients
				def self.call(...)
					new(...)
				end
				
				def initialize(**options, &block)
					@options = options
					@block = block
				end
				
				def close
				end
				
				# Make a new client for the given endpoint.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to create the client for.
				def make_client(endpoint)
					client = Client.new(endpoint, **@options)
					@block&.call(client)
					return client
				end
				
				# Get a client for the given endpoint. If a client already exists for the host, it will be reused.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				def with_client(endpoint)
					client = make_client(endpoint)
					
					yield client
				ensure
					client&.close
				end
				
				# Get a client for the given proxy endpoint and endpoint. If a client already exists for the host, it will be reused.
				#
				# @parameter proxy_endpoint [IO::Endpoint::Generic] The proxy endpoint to use.
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to get the client for.
				def with_proxied_client(proxy_endpoint, endpoint)
					client = client_for(proxy_endpoint)
					proxied_client = client.proxied_client(endpoint)
					
					yield proxied_client 
				ensure
					proxied_client&.close
					client&.close
				end
			end
			
			class PersistentClients < Clients
				def initialize(...)
					super
					
					@clients = {}
				end
				
				def close
					super
					
					clients = @clients.values
					@clients.clear
					
					clients.each(&:close)
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
					
					fetch(key) do
						make_client
					end
				end
				
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
						client_for(proxy_endpoint).proxied_client(endpoint)
					end
					
					yield proxied_client
				end
				
				protected
				
				def fetch(key)
					@clients.fetch(key) do
						@clients[key] = yield
					end
				end
			end
			
			class PerThreadPersistentClients
				def initialize(**options, &block)
					@options = options
					@block = block
					
					@key = :"#{self.class}_#{object_id}"
				end
				
				def with_client(endpoint, &block)
					clients.with_client(endpoint, &block)
				end
				
				def with_proxied_client(proxy_endpoint, endpoint, &block)
					clients.with_proxied_client(proxy_endpoint, endpoint, &block)
				end
				
				def close
					Thread.list.each do |thread|
						if clients = thread[@key]
							clients.close
							
							thread[@key] = nil
						end
					end
				end
				
				protected
				
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
