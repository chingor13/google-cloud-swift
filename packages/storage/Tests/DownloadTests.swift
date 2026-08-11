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

import Crypto
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import GoogleCloudAuth
import GoogleCloudGax
@testable import GoogleCloudStorage
import Testing

@Suite struct DownloadTests {
  private func sampleKey() -> CustomerEncryptionKeyOptions {
    let keyData = Data(repeating: 0x42, count: 32)
    return try! CustomerEncryptionKeyOptions(key: keyData)
  }

  private func makeClient(endpoint: String) throws -> StorageClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let options = StorageClientOptions().with {
      $0.client = .init().with {
        $0.endpoint = endpoint
        $0._testSession = session
        $0.credentials = try! Credentials(configuration: .anonymous)
      }
    }
    return try StorageClient(options)
  }

  @Test func downloadObjectSuccess() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "my-object.txt"
    let payload = Data("Hello, Cloud Storage download!".utf8)

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")

    let headers = [
      "Content-Type": "text/plain; charset=utf-8",
      "Content-Length": String(payload.count),
      "x-goog-generation": "17123456789",
      "x-goog-metageneration": "3",
      "ETag": "\"CPv1234\"",
      "x-goog-hash": "crc32c=AdiAvw==, md5=yTML28a3b45rOPOl4WI23Q==",
      "x-goog-storage-class": "STANDARD",
      "Last-Modified": "Fri, 07 Aug 2026 01:00:00 GMT",
    ]

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: headers),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let result = try await client.readObject(from: bucket, object: objectName)

    #expect(result.metadata.bucket == bucket)
    #expect(result.metadata.object == objectName)
    #expect(result.metadata.size == Int64(payload.count))
    #expect(result.metadata.generation == 17123456789)
    #expect(result.metadata.metageneration == 3)
    #expect(result.metadata.etag == "\"CPv1234\"")
    #expect(result.metadata.crc32c == "AdiAvw==")
    #expect(result.metadata.md5Hash == "yTML28a3b45rOPOl4WI23Q==")
    #expect(result.metadata.contentType == "text/plain; charset=utf-8")
    #expect(result.metadata.storageClass == "STANDARD")
    #expect(result.metadata.updated != nil)

    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test func downloadObjectWithOptions() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "encrypted.bin"
    let csek = sampleKey()
    let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])

    let downloadUrl = registry.url(
      "/storage/v1/b/\(bucket)/o/\(objectName)?alt=media&generation=999&ifGenerationMatch=888"
    )

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: ["Content-Length": "4"]),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.generation = 999
      $0.preconditions = StoragePreconditions().with { $0.ifGenerationMatch = 888 }
      $0.customerEncryptionKey = csek
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)
    #expect(result.metadata.size == 4)

    let lastReq = registry.lastRequest(for: downloadUrl)
    #expect(lastReq != nil)
    #expect(lastReq?.value(forHTTPHeaderField: "x-goog-encryption-algorithm") == "AES256")
    #expect(lastReq?.value(forHTTPHeaderField: "x-goog-encryption-key") == csek.keyBase64)
    #expect(
      lastReq?.value(forHTTPHeaderField: "x-goog-encryption-key-sha256") == csek.keyHashBase64)

    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test(arguments: [
    ("folder/subfolder/file.json", "folder%2Fsubfolder%2Ffile.json"),
    ("file with spaces.txt", "file%20with%20spaces.txt"),
    ("file&name.txt", "file&name.txt"),
    ("file?name.txt", "file%3Fname.txt"),
    ("file#name.txt", "file%23name.txt"),
    (
      "folder/subfolder/file with & and ?.json",
      "folder%2Fsubfolder%2Ffile%20with%20&%20and%20%3F.json"
    ),
  ])
  func downloadObjectWithSpecialCharactersInPath(
    objectName: String, encodedObjectName: String
  ) async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let payload = Data("{}".utf8)

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(encodedObjectName)?alt=media")

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: nil),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let result = try await client.readObject(from: bucket, object: objectName)

    #expect(result.metadata.bucket == bucket)
    #expect(result.metadata.object == objectName)

    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test func downloadObjectErrorHandling() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "missing.txt"

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")

    registry.register(
      response: .success(statusCode: 404, data: Data("Object not found".utf8), headers: nil),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)

    let err = await expectError(DownloadError.self) {
      try await client.readObject(from: bucket, object: objectName)
    }

    if case .unexpectedServerResponse(let statusCode, let message) = err {
      #expect(statusCode == 404)
      #expect(message == "Object not found")
    } else {
      Issue.record("Expected unexpectedServerResponse error")
    }
  }

  @Test func downloadWithAutoCRC32CSuccess() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "crc-success.txt"
    let payload = Data("Hello, World!".utf8)  // CRC32C: TVUQaA==

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    let headers = ["x-goog-hash": "crc32c=TVUQaA=="]

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: headers),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: .auto)
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)
    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test func downloadWithAutoCRC32CMismatch() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "crc-mismatch.txt"
    let payload = Data("Hello, World!".utf8)  // CRC32C: TVUQaA==

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    let headers = ["x-goog-hash": "crc32c=invalid_crc=="]

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: headers),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: .auto)
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)

    let err = await expectError(DownloadError.self) {
      var downloaded = Data()
      for try await chunk in result.body {
        downloaded.append(chunk)
      }
      return downloaded
    }

    if case .checksumMismatch(let expected, let actual, let algorithm) = err {
      #expect(expected == "invalid_crc==")
      #expect(actual == "TVUQaA==")
      #expect(algorithm == "crc32c")
    } else {
      Issue.record("Expected checksumMismatch error, got \(String(describing: err))")
    }
  }

  @Test func downloadWithAutoMD5Success() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "md5-success.txt"
    let payload = Data("Hello, World!".utf8)  // MD5: ZajifYh5KDgxtmS9i38K1A==

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    let headers = ["x-goog-hash": "md5=ZajifYh5KDgxtmS9i38K1A=="]

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: headers),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: nil, md5: .auto)
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)
    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test func downloadWithAutoMD5Mismatch() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "md5-mismatch.txt"
    let payload = Data("Hello, World!".utf8)  // MD5: ZajifYh5KDgxtmS9i38K1A==

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    let headers = ["x-goog-hash": "md5=wrong_md5=="]

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: headers),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: nil, md5: .auto)
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)

    let err = await expectError(DownloadError.self) {
      var downloaded = Data()
      for try await chunk in result.body {
        downloaded.append(chunk)
      }
      return downloaded
    }

    if case .checksumMismatch(let expected, let actual, let algorithm) = err {
      #expect(expected == "wrong_md5==")
      #expect(actual == "ZajifYh5KDgxtmS9i38K1A==")
      #expect(algorithm == "md5")
    } else {
      Issue.record("Expected checksumMismatch error, got \(String(describing: err))")
    }
  }

  @Test func downloadWithProvidedCRC32CValue() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "provided-crc.txt"
    let payload = Data("Hello, World!".utf8)  // CRC32C: TVUQaA==

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: nil),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: "TVUQaA==")
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)
    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test func downloadWithProvidedCRC32CValueMismatch() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "provided-crc-mismatch.txt"
    let payload = Data("Hello, World!".utf8)

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: nil),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: "bad_crc")
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)

    let err = await expectError(DownloadError.self) {
      var downloaded = Data()
      for try await chunk in result.body {
        downloaded.append(chunk)
      }
      return downloaded
    }

    if case .checksumMismatch(let expected, let actual, let algorithm) = err {
      #expect(expected == "bad_crc")
      #expect(actual == "TVUQaA==")
      #expect(algorithm == "crc32c")
    } else {
      Issue.record("Expected checksumMismatch error")
    }
  }

  @Test func downloadWithProvidedCRC32CWithPrefix() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "prefix-crc.txt"
    let payload = Data("Hello, World!".utf8)

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: nil),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: "crc32c=TVUQaA==")
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)
    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }

  @Test func downloadWithProvidedMD5Value() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "provided-md5.txt"
    let payload = Data("Hello, World!".utf8)  // MD5: ZajifYh5KDgxtmS9i38K1A==

    let downloadUrl = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")

    registry.register(
      response: .success(statusCode: 200, data: payload, headers: nil),
      for: downloadUrl
    )

    let client = try makeClient(endpoint: registry.endpoint)
    let options = ReadObjectOptions().with {
      $0.checksums = ChecksumOptions(crc32c: nil, md5: "ZajifYh5KDgxtmS9i38K1A==")
    }

    let result = try await client.readObject(from: bucket, object: objectName, options: options)
    var downloaded = Data()
    for try await chunk in result.body {
      downloaded.append(chunk)
    }
    #expect(downloaded == payload)
  }
}
