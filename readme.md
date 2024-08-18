# Async::HTTP::Faraday

Provides an adaptor for [Faraday](https://github.com/lostisland/faraday) to perform async HTTP requests. If you are designing a new library, you should probably just use `Async::HTTP::Client` directly. However, for existing projects and libraries that use Faraday as an abstract interface, this can be a drop-in replacement to improve concurrency. It should be noted that the default `Net::HTTP` adapter works perfectly okay with Async, however it does not use persistent connections by default.

  - Persistent connections by default.
  - Supports HTTP/1 and HTTP/2 (and HTTP/3 in the future).

[![Development Status](https://github.com/socketry/async-http-faraday/workflows/Test/badge.svg)](https://github.com/socketry/async-http-faraday/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-http/) for more details.

  - [Getting Started](https://socketry.github.io/async-http/guides/getting-started/index) - This guide explains how to use use `Async::HTTP::Faraday` as a drop-in replacement for improved concurrency.

## Releases

Please see the [project changes](https://socketry.github.io/async-http//changes/index) for all releases.

### v0.18.0

  - [Config Block](https://socketry.github.io/async-http/changes/index#config-block)

### v0.17.0

  - [Per-thread Client Cache](https://socketry.github.io/async-http/changes/index#per-thread-client-cache)

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
