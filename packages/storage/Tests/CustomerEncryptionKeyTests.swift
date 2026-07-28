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
import GoogleCloudGax
@testable import GoogleCloudStorage
import Testing

@Suite struct CustomerEncryptionKeyOptionsTests {
  /// Helper to create a sample 32-byte key and its expected Base64 and SHA-256 Base64 values.
  private func sampleKey() -> (data: Data, keyBase64: String, keyHashBase64: String) {
    let keyData = Data(repeating: 0x42, count: 32)
    let keyBase64 = keyData.base64EncodedString()
    let sha256Digest = SHA256.hash(data: keyData)
    let keyHashBase64 = Data(sha256Digest).base64EncodedString()
    return (keyData, keyBase64, keyHashBase64)
  }

  @Test func createFromData() throws {
    let sample = sampleKey()
    let csek = try CustomerEncryptionKeyOptions(key: sample.data)

    #expect(csek.algorithm == "AES256")
    #expect(csek.keyBase64 == sample.keyBase64)
    #expect(csek.keyHashBase64 == sample.keyHashBase64)
    #expect(csek.description == sample.keyBase64)
  }

  @Test func createFromByteArray() throws {
    let sample = sampleKey()
    let bytes = Array(sample.data)
    let csek = try CustomerEncryptionKeyOptions(keyBytes: bytes)

    #expect(csek.algorithm == "AES256")
    #expect(csek.keyBase64 == sample.keyBase64)
    #expect(csek.keyHashBase64 == sample.keyHashBase64)
  }

  @Test func createFromBase64String() throws {
    let sample = sampleKey()
    let csek = try CustomerEncryptionKeyOptions(keyBase64: sample.keyBase64)

    #expect(csek.algorithm == "AES256")
    #expect(csek.keyBase64 == sample.keyBase64)
    #expect(csek.keyHashBase64 == sample.keyHashBase64)
  }

  @Test func createFromPrecomputedValues() {
    let csek = CustomerEncryptionKeyOptions(
      algorithm: "AES256",
      keyBase64: "customKeyBase64==",
      keyHashBase64: "customHashBase64=="
    )
    #expect(csek.algorithm == "AES256")
    #expect(csek.keyBase64 == "customKeyBase64==")
    #expect(csek.keyHashBase64 == "customHashBase64==")
  }

  @Test func invalidKeyLengthThrows() {
    let shortKey = Data(repeating: 0x01, count: 16)
    #expect(throws: CustomerEncryptionKeyError.invalidKeyLength(actual: 16, expected: 32)) {
      try CustomerEncryptionKeyOptions(key: shortKey)
    }

    let longKey = Data(repeating: 0x01, count: 33)
    #expect(throws: CustomerEncryptionKeyError.invalidKeyLength(actual: 33, expected: 32)) {
      try CustomerEncryptionKeyOptions(key: longKey)
    }
  }

  @Test func invalidBase64StringThrows() {
    #expect(throws: CustomerEncryptionKeyError.invalidBase64Key) {
      try CustomerEncryptionKeyOptions(keyBase64: "not-valid-base64!@#$")
    }
  }

  @Test func equatableAndHashable() throws {
    let sample = sampleKey()
    let key1 = try CustomerEncryptionKeyOptions(key: sample.data)
    let key2 = try CustomerEncryptionKeyOptions(keyBase64: sample.keyBase64)
    #expect(key1 == key2)
    #expect(key1.hashValue == key2.hashValue)
  }

  @Test func simpleUploadWithCSEKHeaders() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-csek-object"
    let data = Data(repeating: 1, count: 1024)
    let source = BytesSource(data: data)

    let sample = sampleKey()
    let csek = try CustomerEncryptionKeyOptions(key: sample.data)

    let simpleUploadUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=multipart&name=\(objectName)")

    let responseJSON = """
      {
        "name": "\(objectName)",
        "bucket": "\(bucket)",
        "generation": "1",
        "metageneration": "1",
        "size": "\(data.count)",
        "contentType": "application/octet-stream",
        "customerEncryption": {
          "encryptionAlgorithm": "AES256",
          "keySha256": "\(sample.keyHashBase64)"
        }
      }
      """

    registry.register(
      response: .success(
        statusCode: 200, data: responseJSON.data(using: .utf8)!,
        headers: nil),
      for: simpleUploadUrl)

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let options = StorageClientOptions().with {
      $0.client = .init().with {
        $0.endpoint = registry.endpoint
        $0._testSession = session
      }
    }

    let client = try StorageClient(options)
    let uploadOptions = UploadOptions(customerEncryptionKey: csek)
    let task = client.upload(source, to: bucket, as: objectName, options: uploadOptions)
    let object = try await task.value

    #expect(object.name == objectName)
    #expect(object.customerEncryption?.encryptionAlgorithm == "AES256")
    #expect(object.customerEncryption?.keySha256 == sample.keyHashBase64)

    let requests = registry.recordedRequests()
    #expect(!requests.isEmpty)
    let uploadReq = requests.first {
      $0.url?.path.contains("/upload/storage/v1/b/\(bucket)/o") == true
    }
    #expect(uploadReq != nil)
    #expect(uploadReq?.value(forHTTPHeaderField: "x-goog-encryption-algorithm") == "AES256")
    #expect(uploadReq?.value(forHTTPHeaderField: "x-goog-encryption-key") == sample.keyBase64)
    #expect(
      uploadReq?.value(forHTTPHeaderField: "x-goog-encryption-key-sha256") == sample.keyHashBase64)
  }

  @Test func resumableUploadWithCSEKHeaders() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-csek-resumable"
    let data = Data(repeating: 1, count: 10 * 1024 * 1024)
    let source = BytesSource(data: data)

    let sample = sampleKey()
    let csek = try CustomerEncryptionKeyOptions(key: sample.data)

    let startUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=resumable&name=\(objectName)")
    let chunkUrl = registry.url("/upload/storage/v1/b/\(bucket)/o?upload_id=csek-upload-id")

    let responseJSON = """
      {
        "name": "\(objectName)",
        "bucket": "\(bucket)",
        "generation": "1",
        "metageneration": "1",
        "size": "\(data.count)",
        "contentType": "application/octet-stream",
        "customerEncryption": {
          "encryptionAlgorithm": "AES256",
          "keySha256": "\(sample.keyHashBase64)"
        }
      }
      """

    registry.register(
      response: .success(
        statusCode: 200, data: Data(),
        headers: ["Location": chunkUrl.absoluteString]),
      for: startUrl)
    registry.register(
      response: .success(
        statusCode: 200, data: responseJSON.data(using: .utf8)!,
        headers: nil),
      for: chunkUrl)

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let options = StorageClientOptions().with {
      $0.client = .init().with {
        $0.endpoint = registry.endpoint
        $0._testSession = session
      }
    }

    let client = try StorageClient(options)
    let uploadOptions = UploadOptions(customerEncryptionKey: csek)
    let task = client.upload(source, to: bucket, as: objectName, options: uploadOptions)
    let object = try await task.value

    #expect(object.name == objectName)
    #expect(object.customerEncryption?.keySha256 == sample.keyHashBase64)

    let requests = registry.recordedRequests()
    #expect(requests.count == 2)

    // Verify start request headers
    let startReq = requests[0]
    #expect(startReq.value(forHTTPHeaderField: "x-goog-encryption-algorithm") == "AES256")
    #expect(startReq.value(forHTTPHeaderField: "x-goog-encryption-key") == sample.keyBase64)
    #expect(
      startReq.value(forHTTPHeaderField: "x-goog-encryption-key-sha256") == sample.keyHashBase64)

    // Verify chunk PUT request headers
    let chunkReq = requests[1]
    #expect(chunkReq.value(forHTTPHeaderField: "x-goog-encryption-algorithm") == "AES256")
    #expect(chunkReq.value(forHTTPHeaderField: "x-goog-encryption-key") == sample.keyBase64)
    #expect(
      chunkReq.value(forHTTPHeaderField: "x-goog-encryption-key-sha256") == sample.keyHashBase64)
  }
}
