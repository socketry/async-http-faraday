require 'vcr'

VCR.configure do |config|
	config.cassette_library_dir = 'spec/cassettes'
	config.hook_into :faraday
	config.ignore_localhost = true
end

# support Faraday::Adapter#close until PR https://github.com/vcr/vcr/pull/793 is merged
class VCR::Middleware::Faraday
	def close
		@app.close
	end
end
