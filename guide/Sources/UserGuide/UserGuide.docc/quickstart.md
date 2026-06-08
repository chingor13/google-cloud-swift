# Quickstart

## Install Swift

If you have not installed the Swift toolchain, follow the [Installing Swift]
instructions.

## Create a Google Cloud Project

If you do not have a Google Cloud project, follow the
[Get started with Google Cloud] guide.

## Authenticate to Google Cloud

Follow the instructions in the [Authenticate for using client libraries] guide.
This guide will show you how to login to configure [Application Default Credentials]
used in this guide.

## Create a Swift project

In this guide we will create a CLI to access Google Cloud. Initialize your
Swift project using:

```bash
mkdir GoogleCloudCLI
cd GoogleCloudCLI
swift package init --name GoogleCloudCLI --type executable
```

## Install the Google Cloud Client Libraries

At the moment, you need to extract the client libraries as source code. In your
project directory run:

```bash
# Replace the [REPO SOURCE] placeholder with the actual location of the code.
git clone [REPO SOURCE] google-cloud-swift
```

## Add the client library as a dependency

Edit your `Package.swift` to add `GoogleCloudSecretmanagerV1` as a dependency.
It should read:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "GoogleCloudCLI",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(path: "google-cloud-swift/generated/google-cloud-secretmanager-v1")
  ],
  targets: [
    .executableTarget(
      name: "GoogleCloudCLI",
      dependencies: [
        .product(name: "GoogleCloudSecretmanagerV1", package: "google-cloud-secretmanager-v1")
      ],
    )
  ],
)
```

## Import the dependencies

```swift
import Foundation
import GoogleCloudSecretmanagerV1
```

## Create the entry point for your program

```swift
@main
struct GoogleCloudCLI {
  static func main() async throws {
```

## Get a project id

Get your project id from the command-line:

```swift
    let args = CommandLine.arguments.dropFirst()
    guard let projectId = args.first else {
      print("Usage: GoogleCloudCLI <projectId>")
      exit(1)
    }
```

## Initialize the client

Initialize the client with the defaults:

```swift
    let client = try GoogleCloudSecretmanagerV1.Clients.SecretManagerServiceClient()
```

## List the secrets

And then list the secrets:

```swift
    let secrets = try client.listSecrets(
      byItem: ListSecretsRequest().with { $0.parent = "projects/\(projectId)" })
    for try await item in secrets {
      print("  \(item)")
    }
```

## Running the program

Run the program:

```bash
# Replace the [PROJECT ID] placeholder with the id of your project
swift run GoogleCloudCLI [PROJECT ID]
```

## Full code

The full code for your program should look like this:

```swift
import Foundation
import GoogleCloudSecretmanagerV1

@main
struct GoogleCloudCLI {
  static func main() async throws {
    let args = CommandLine.arguments.dropFirst()
    guard let projectId = args.first else {
      print("Usage: GoogleCloudCLI <projectId>")
      exit(1)
    }
    let client = try GoogleCloudSecretmanagerV1.Clients.SecretManagerServiceClient()
    let secrets = try client.listSecrets(
      byItem: ListSecretsRequest(parent: "projects/\(projectId)"))
    for try await item in secrets {
      print("  \(item)")
    }
  }
}
```

[Installing Swift]: https://www.swift.org/getting-started/
[Authenticate for using client libraries]: https://cloud.google.com/docs/authentication/client-libraries
[Application Default Credentials]: https://cloud.google.com/docs/authentication/application-default-credentials
[Get started with Google Cloud]: https://docs.cloud.google.com/docs/get-started
