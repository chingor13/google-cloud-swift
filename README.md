# Google Cloud API Client Libraries for Swift

Idiomatic Swift client libraries for
[Google Cloud Platform](https://cloud.google.com/) services.

## Status

The project is just starting, we are experimenting with its structure and design.

## Minimum Supported Swift Version

We require Swift >= 6.2. We plan to update this periodically. However, the
development branch will always compile with the Swift versions released within
the previous year.

## Semantic versioning

We will make every effort to avoid breaking changes once a library reaches 1.0.

With that said, many of the crates in this project are automatically generated
from the service specification. From time to time these service specifications
may introduce breaking changes. We make reasonable efforts, and use tooling, to
detect such breaking changes. When we detect a breaking change we will bump the
major version (or minor for crates still at `0.x`).

We do not consider changes to `swift-tools-version` to be breaking changes.

We do not consider changes to our dependencies, or the features enabled in our
dependencies, to be breaking changes. You should add any dependencies to your
application directly, and enable any non-default features of these dependencies
explicitly.

### Non-public API

We plan to reserve a portion of the namespace.

## Contributing

Contributions to this library are always welcome and highly encouraged.

See [CONTRIBUTING] for more information on how to get started. You may also find
the [Set Up Development Environment] guide useful.

## License

Apache 2.0 - See [LICENSE] for more information.

[contributing]: CONTRIBUTING.md
[license]: LICENSE
[set up development environment]: doc/contributor/howto-guide-set-up-development-environment.md
