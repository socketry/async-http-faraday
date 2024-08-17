# v0.18.0

## Config Block

The `config_block` provided to the adapter must now return `nil`, `client` or a middleware wrapper around `client`.

```ruby
Faraday.new do |builder|
	builder.adapter :async_http do |client|
		# Option 1 (same as returning `nil`), use client as is:
		client # Use `client` as is.
		
		# Option 2, wrap client in a middleware:
		Async::HTTP::Middleware::LocationRedirector.new(client)
	end
end
```
