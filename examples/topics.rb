#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require 'async'
require 'faraday'
require 'async/http/faraday'

# Async.logger.debug!

module TestAsync
	URL = 'https://www.google.com/search'
	TOPICS = %W{ruby python lisp javascript cobol}
	
	def self.fetch_topics_async
		TOPICS.map do |topic|
			Async do
				Faraday.get("#{URL}?q=#{topic}")
			end
		end.map(&:wait)
	end
end

Faraday.default_adapter = :async_http

Async do
	pp TestAsync.fetch_topics_async
ensure
	# This line is fairly essential if you intend to exit from the async block.
	Faraday.default_connection.close
end

