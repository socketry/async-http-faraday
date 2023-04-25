# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

begin
	require 'sawyer/agent'
	
	# This is a nasty hack until https://github.com/lostisland/sawyer/pull/67 is resolved:
	unless Sawyer::Agent.instance_methods.include?(:close)
		class Sawyer::Agent
			def close
				@conn.close if @conn.respond_to?(:close)
			end
		end
	end
rescue LoadError
	# Ignore.
end
