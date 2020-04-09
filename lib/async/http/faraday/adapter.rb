# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'faraday'
require 'faraday/adapter'
require 'kernel/sync'
require 'async/http/internet'
require 'async/clock'

require_relative 'agent'

module Async
	module HTTP
		module Faraday
			# Detect whether we can use persistent connections:
			PERSISTENT = ::Faraday::Connection.instance_methods.include?(:close)
			
			class Adapter < ::Faraday::Adapter
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

				def initialize(*arguments, **options, &block)
					super
					
					@internet = Async::HTTP::Internet.new
					@persistent = PERSISTENT && options.fetch(:persistent, true)
					@timeout = options[:timeout]
				end
				
				def close
					@internet.close
				end
				
				def call(env)
					super
					
					parent = Async::Task.current?
					response = nil
					
					Sync do
						with_timeout do
							start = Async::Clock.now
							Async.logger.info(self) {"#{env[:method]} -> #{env[:url]}"}
							response = @internet.call(env[:method].to_s.upcase, env[:url].to_s, env[:request_headers], env[:body] || [])
							
							save_response(env, response.status, response.read, response.headers)
							Async.logger.info(self) {"#{env[:method]} <- #{env[:url]} (#{(Async::Clock.now - start).round(3)}s)"}
						end
					ensure
						# If we are the top level task, even if we are persistent, we must close the connection:
						if parent.nil? || !@persistent
							# if response.connection.count == 1
							# 	puts "*" * 30
							# 	puts "#{env[:method]} #{env[:url]} #{response.connection.count}"
							# 	puts caller
							# end
							
							@internet.close
						end
					end
					
					return @app.call(env)
				rescue Errno::ETIMEDOUT, Async::TimeoutError => e
					raise ::Faraday::TimeoutError, e
				rescue OpenSSL::SSL::SSLError => e
					raise ::Faraday::SSLError, e
				rescue *CONNECTION_EXCEPTIONS => e
					raise ::Faraday::ConnectionFailed, e
				end

				private

				def with_timeout(task: Async::Task.current)
					if @timeout
						task.with_timeout(@timeout, ::Faraday::TimeoutError) do
							yield
						end
					else
						yield
					end
				end
			end
		end
	end
end
