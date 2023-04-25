# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2020, by Samuel Williams.

require_relative "faraday/version"
require_relative "faraday/adapter"

Faraday::Adapter.register_middleware :async_http => Async::HTTP::Faraday::Adapter
