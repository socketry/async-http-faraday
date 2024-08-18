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

# v0.17.0

## Per-thread Client Cache

The default adapter now uses a per-thread client cache internally, to improve compatibility with existing code that shares a single `Faraday::Connection` instance across multiple threads.

```ruby
adapter = Faraday.new do |builder|
	builder.adapter :async_http
end

3.times do
	Thread.new do
		Async do
			# Each thread has it's own client cache.
			adapter.get('http://example.com')
		end
	end
end
```
