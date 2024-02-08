# Async::HTTP::Faraday

Provides an adaptor for [Faraday](https://github.com/lostisland/faraday) to perform async HTTP requests. If you are designing a new library, you should probably just use `Async::HTTP::Client` directly.

[![Development Status](https://github.com/socketry/async-http-faraday/workflows/Test/badge.svg)](https://github.com/socketry/async-http-faraday/actions?workflow=Test)

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'async-http-faraday'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install async-http-faraday

## Usage

Here is how you set faraday to use `Async::HTTP`:

``` ruby
require 'async/http/faraday'

# Make it the global default:
Faraday.default_adapter = :async_http

# Per connection:
connection = Faraday.new(...) do |builder|
	builder.adapter :async_http
end
```

Here is how you make a request:

``` ruby
Async do
	response = connection.get("/index")
end
```

### Default

To make this the default adaptor:

``` ruby
require 'async/http/faraday/default'
```

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

This project uses the [Developer Certificate of Origin](https://developercertificate.org/). All contributors to this project must agree to this document to have their contributions accepted.

### Contributor Covenant

This project is governed by the [Contributor Covenant](https://www.contributor-covenant.org/). All contributors and participants agree to abide by its terms.
