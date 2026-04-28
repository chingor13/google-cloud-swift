# Integration tests for Protobuf-based client

This directory contains integration tests for a Protobuf-based client. The tests
use the `GoogleCloudSecretmanagerV1` library, because it is easy to enable this
library, the quota is fairly generous for integration tests, and because it
covers a number of features including:

- Multiple data types, including maps, bytes, timestamps, and field masks.
- Nested messages, nested enums, and other complex types.
- The location and IAM mixins.
- Pagination.
- Some regional endpoints.

The service does not use some features, such as:

- The LRO mixin.
- Recursive messages.
- Use of `Any` in the service.

We (will) have separate tests for these additional features. In fact, it is
better to have a service with some limitations to start testing early.
