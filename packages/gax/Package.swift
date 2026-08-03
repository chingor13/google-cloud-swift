// swift-tools-version: 6.2
//
// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

let package = Package(
  name: "GoogleCloudGax",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "GoogleCloudGax", targets: ["GoogleCloudGax"])
  ],
  traits: [
    "IntegrationTests"
  ],
  dependencies: [
    .package(path: "../auth"),
    .package(path: "../../generated/google-rpc"),
    .package(url: "https://github.com/apple/swift-log", from: "1.12.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
  ],
  targets: [
    .target(
      name: "GoogleCloudGax",
      dependencies: [
        .product(name: "GoogleCloudAuth", package: "auth"),
        .product(name: "GoogleRpc", package: "google-rpc"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
      ]
    ),
    .testTarget(
      name: "GoogleCloudGaxTests",
      dependencies: [
        "GoogleCloudGax",
        .product(name: "GoogleRpc", package: "google-rpc"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOTestUtils", package: "swift-nio"),
      ],
      path: "Tests",
      exclude: ["IntegrationTests"]
    ),
    .testTarget(
      name: "GoogleCloudGaxIntegrationTests",
      dependencies: [
        "GoogleCloudGax"
      ],
      path: "Tests/IntegrationTests"
    ),
  ]
)
