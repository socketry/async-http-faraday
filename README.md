# Async::HTTP::Faraday

Provides an adaptor for [Faraday] to perform async HTTP requests. If you are designing a new library, you should probably just use `Async::HTTP::Client` directly.

[![Build Status](https://secure.travis-ci.org/socketry/async-http-faraday.svg)](http://travis-ci.org/socketry/async-http-faraday)
[![Code Climate](https://codeclimate.com/github/socketry/async-http-faraday.svg)](https://codeclimate.com/github/socketry/async-http-faraday)
[![Coverage Status](https://coveralls.io/repos/socketry/async-http-faraday/badge.svg)](https://coveralls.io/r/socketry/async-http-faraday)

[async]: https://github.com/socketry/async
[async-io]: https://github.com/socketry/async-io
[Faraday]: https://github.com/lostisland/faraday

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'async-http-faraday'
```

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install async-http-faraday

## Usage

Here is how you set faraday to use `Async::HTTP`:

```ruby
require 'async/http/faraday'

# Make it the global default:
Faraday.default_adapter = :async_http

# Per connection:
conn = Faraday.new(...) do |faraday|
  faraday.adapter :async_http
end
```

Here is how you make a request:

```ruby
Async::Reactor.run do
  conn.get "/index"
ensure
  # This line is fairly essential if you intend to exit from the async block.
  conn.close
end
```

Please check `examples` folder for more examples.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Released under the MIT license.

Copyright, 2015, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
