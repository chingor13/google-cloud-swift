# Use multiple client libraries

<!--
    It seems that swift-docc does not support reference-style links at the bottom of the file:

    https://github.com/swiftlang/swift-docc/issues/685
-->
[Getting started with Swift]: <doc:quickstart>
[secret manager api]: https://cloud.google.com/secret-manager
[workflows api]: https://cloud.google.com/workflows

Applications often interact with more than one Google Cloud service in the same
target or source file—for example, reading secrets from [Secret Manager API]
while orchestrating executions with the [Workflows API]. This guide shows how
to configure dependencies, initialize multiple clients, and disambiguate symbol
names when importing multiple client libraries in a single Swift file.

## Prerequisites

For complete setup instructions for the Swift client libraries, see
[Getting started with Swift].

## Add multiple client libraries to `Package.swift`

Add each service package to `dependencies` and link its module product to your
target in `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/googleapis/swift-google-cloud-secretmanager-v1.git",
    from: "0.2.0"
  ),
  .package(
    url: "https://github.com/googleapis/swift-google-cloud-workflows-v1.git",
    from: "0.2.0"
  ),
],
targets: [
  .executableTarget(
    name: "MyApp",
    dependencies: [
      .product(
        name: "GoogleCloudSecretManagerV1",
        package: "swift-google-cloud-secretmanager-v1"
      ),
      .product(
        name: "GoogleCloudWorkflowsV1",
        package: "swift-google-cloud-workflows-v1"
      ),
    ]
  )
]
```

## Disambiguate `Clients` and shared symbol names

Each generated client module declares a top-level `Clients` namespace containing
the service protocol used for mocking and dependency injection (such as
`Clients.SecretManagerServiceProtocol` and `Clients.WorkflowsProtocol`). When a
single Swift file imports two or more Google Cloud client modules, referencing
`Clients` without a module prefix results in a compiler error:

```text
error: 'Clients' is ambiguous for type lookup in this context
```

To avoid this ambiguity:

1. Import the client modules you need:
   @Snippet(path: "UsingMultipleClients", slice: "imports")
2. Module-qualify `Clients` with the package's module name, or define a
   `typealias` for each service protocol:
   @Snippet(path: "UsingMultipleClients", slice: "typealiases")
3. Accept the protocol types in functions or types that need to support
   dependency injection or unit test mocks:
   @Snippet(path: "UsingMultipleClients", slice: "function")
4. Initialize the concrete client instances and pass them to your functions:
   @Snippet(path: "UsingMultipleClients", slice: "clients")

> Tip: The same module-qualification pattern (`<Module>.<Type>`) also resolves
> collisions if two services define protobuf message types with identical names
> in the same file.

## Full code

@Snippet(path: "UsingMultipleClients")
