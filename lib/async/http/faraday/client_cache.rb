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
			class ClientCache
				def initialize(**options)
					@options = options
					@clients = {}
				end
				
				def close
					clients = @clients.values
					@clients.clear
					
					clients.each(&:close)
				end
				
				# Make a new client for the given endpoint.
				#
				# @parameter endpoint [IO::Endpoint::Generic] The endpoint to create the client for.
				def make_client(endpoint)
					Client.new(endpoint, **@options)
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
			end
		end
	end
end
