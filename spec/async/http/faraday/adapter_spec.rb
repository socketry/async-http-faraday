# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2021, by Samuel Williams.
# Copyright, 2018, by Andreas Garnaes.
# Copyright, 2019, by Denis Talakevich.
# Copyright, 2019-2020, by Igor Sidorov.
# Copyright, 2023, by Genki Takiuchi.

require 'async/http/faraday'
require 'async/http/server'
require 'async/http/endpoint'

require 'async'

RSpec.describe Async::HTTP::Faraday::Adapter do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {
		Async::HTTP::Endpoint.parse('http://127.0.0.1:9294')
	}
	
	def run_server(response = Protocol::HTTP::Response[204], response_delay: nil)
		Sync do |task|
			begin
				server_task = task.async do
					app = Proc.new do
						if response_delay
							task.sleep(response_delay)
						end
						
						response
					end
					
					Async::HTTP::Server.new(app, endpoint).run
				end
				
				yield
			ensure
				server_task.stop
			end
		end
	end
	
	def get_response(url = endpoint.url, path = '/index', adapter_options: {})
		connection = Faraday.new(url) do |faraday|
			faraday.response :logger
			faraday.adapter :async_http, **adapter_options
		end
		
		connection.get(path)
	
	ensure
		connection&.close
	end
	
	it "client can get resource" do
		run_server(Protocol::HTTP::Response[200, {}, ['Hello World']]) do
			expect(get_response.body).to eq 'Hello World'
		end
	end

  it "client can get responce with respect to Content-Type encoding" do
    run_server(Protocol::HTTP::Response[200, {'Content-Type' => 'text/html; charset=utf-8'}, ['こんにちは世界']]) do
      body = get_response.body
      expect(body.encoding).to eq Encoding::UTF_8
      expect(body).to eq 'こんにちは世界'
    end
  end

	
	it "works without top level reactor" do
		response = get_response("https://www.google.com", "/search?q=ruby")
		
		expect(response).to be_success
	end
	
	it "can get remote resource" do
		Sync do
			response = get_response('http://www.google.com', '/search?q=cats')
			
			expect(response).to be_success
		end
	end
	
	it 'properly handles chunked responses' do
		large_response_size = 65536
		
		run_server(Protocol::HTTP::Response[200, {}, ['.' * large_response_size]]) do
			expect(get_response.body.size).to eq large_response_size
		end
	end
	
	it 'properly handles no content responses' do
		run_server(Protocol::HTTP::Response[204]) do
			expect(get_response.body).to be_nil
		end
	end
	
	it 'raises an exception if request times out' do
		delay = 0.1
		
		run_server(response_delay: delay) do
			expect do
				get_response(adapter_options: {timeout: delay / 2})
			end.to raise_error(Faraday::TimeoutError)
			
			expect do
				get_response(adapter_options: {timeout: delay * 2})
			end.not_to raise_error
		end
	end
	
	it 'wraps underlying exceptions into Faraday analogs' do
		expect { get_response(endpoint.url, '/index') }.to raise_error(Faraday::ConnectionFailed)
	end
end
