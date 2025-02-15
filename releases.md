# Releases

## v0.21.0

### Improved support for `timeout` and `read_timeout`.

Previously, only a per-connection `timeout` was supported, but now:

1.  `timeout` can be set per request too.
2.  `read_timeout` can be set per adapter and is assigned to `IO#timeout` if available.

This improves compatibility with existing code that uses `timeout` and `read_timeout`.

## v0.20.0

  - Implement the new response streaming interface, which provides the initial response status code and headers before streaming the response body.
  - An empty response now sets the response body to an empty string rather than `nil` as required by the Faraday specification.

## v0.19.0

### Support `in_parallel`.

The adapter now supports the `in_parallel` method, which allows multiple requests to be made concurrently.

``` ruby
adapter = Faraday.new(bound_url) do |builder|
	builder.adapter :async_http
end

response1 = response2 = response3 = nil

adapter.in_parallel do
	response1 = adapter.get("/index")
	response2 = adapter.get("/index")
	response3 = adapter.get("/index")
end

puts response1.body # => "Hello World"
puts response2.body # => "Hello World"
puts response3.body # => "Hello World"
```

This is primarily for compatibility with existing code. If you are designing a new library, you should just use `Async` directly:

``` ruby
Async do
	response1 = Async{adapter.get("/index")}
	response2 = Async{adapter.get("/index")}
	response3 = Async{adapter.get("/index")}
	
	puts response1.wait.body # => "Hello World"
	puts response2.wait.body # => "Hello World"
	puts response3.wait.body # => "Hello World"
end
```

## v0.18.0

### Support for `config_block` returning a middleware wrapper.

The `config_block` provided to the adapter must now return `nil`, `client` or a middleware wrapper around `client`.

``` ruby
Faraday.new do |builder|
	builder.adapter :async_http do |client|
		# Option 1 (same as returning `nil`), use client as is:
		client # Use `client` as is.
		
		# Option 2, wrap client in a middleware:
		Async::HTTP::Middleware::LocationRedirector.new(client)
	end
end
```

## v0.17.0

### Introduced a per-thread `Client` cache.

The default adapter now uses a per-thread client cache internally, to improve compatibility with existing code that shares a single `Faraday::Connection` instance across multiple threads.

``` ruby
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
