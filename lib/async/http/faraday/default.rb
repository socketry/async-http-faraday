# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require_relative "register"

# Set the default adapter to use Async::HTTP.
::Faraday.default_adapter = :async_http
