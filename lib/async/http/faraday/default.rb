# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require_relative 'adapter'

::Faraday.default_adapter = :async_http
