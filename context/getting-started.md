# Getting Started

This guide explains how to use use `Async::HTTP::Faraday` as a drop-in replacement for improved concurrency.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async-http-faraday
~~~

## Usage

The simplest way to use `Async::HTTP::Faraday` is to set it as the default adapter for Faraday. This will make all requests asynchronous.

~~~ ruby
require 'async/http/faraday/default'
~~~

This will configure `Faraday.default_adapter`.

### Custom Connection

You can configure a custom connection to use the async adapter:

``` ruby
# Per connection:
connection = Faraday.new do |builder|
	builder.adapter :async_http
end
```

Here is how you make a request:

``` ruby
response = connection.get("/index")
```

### Thread Safety

By default, the faraday adapter uses a per-thread persistent client cache. This is safe to use in multi-threaded environments, in other words, if you have a single global faraday connection, and use that everywhere, it will be thread-safe. However, a consequence of that is you may experience elevated memory usage if you have many threads, as each thread will have its own connection pool. This is a desirable share-nothing architecture which helps to isolate problems, but if you don't use a multi-threaded environment, you may want to avoid the overhead. You can do this by configuring the `clients` option:

~~~ruby
connection = Faraday.new(...) do |builder|
	# The default `clients:` is `Async::HTTP::Faraday::PerThreadPersistentClients`.
	builder.adapter :async_http, clients: Async::HTTP::Faraday::PersistentClients
end
~~~

The value of isolation cannot be overstated - if you can design you program using a share-nothing (between threads) architecture, you will have a much easier time debugging and reasoning about your program, however this comes at the cost of increased resource usage.

Alternatively, if you do not want to cache client connections, you can use the `Async::HTTP::Faraday::Clients` interface, which closes the connection after each request:

~~~ruby
connection = Faraday.new(...) do |builder|
	builder.adapter :async_http, clients: Async::HTTP::Faraday::Clients
end
~~~

This will reduce memory usage but increase the latency of every request.

### Retrying Failed Requests

An HTTP/2 stream reset can interrupt a response after its headers have arrived. The adapter translates {ruby Protocol::HTTP2::StreamError} and {ruby Protocol::HTTP::RemoteError} into {ruby Faraday::ConnectionFailed}, preserving the original exception as its cause. This translation does not add retries or classify every possible body-read exception.

For requests whose incomplete responses can be discarded, you can configure `faraday-retry` to repeat the request. This example allows up to two retries with backoff for bodyless `GET` and `HEAD` requests:

~~~ruby
require "faraday/retry"

connection = Faraday.new("https://api.example.com") do |builder|
	builder.request :retry, max: 2, interval: 0.1, backoff_factor: 2,
		methods: [:get, :head], exceptions: [Faraday::ConnectionFailed]
	builder.adapter :async_http
end
~~~

Async HTTP already retries eligible failures before returning a response. Faraday retries encompass response-body consumption as well, and can repeat requests after the internal attempts have been exhausted. Each Faraday attempt may therefore involve several underlying attempts; configure retry limits and an overall deadline accordingly.

Idempotency alone is not sufficient for requests with bodies, such as `PUT`: the body must also be replayable. Do not assume that `faraday-retry` rewinds arbitrary IO or streaming bodies. Ensure that the complete request body is restored before each attempt. When streaming response chunks to a callback, ensure that partial output can be discarded or that repeated chunks can be handled safely before enabling retries.
