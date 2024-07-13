# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require_relative "faraday/version"
require_relative "faraday/adapter"

Faraday::Adapter.register_middleware :async_http => Async::HTTP::Faraday::Adapter

# @namespace
module Async
	# @namespace
	module HTTP
		# @namespace
		module Faraday
		end
	end
end
