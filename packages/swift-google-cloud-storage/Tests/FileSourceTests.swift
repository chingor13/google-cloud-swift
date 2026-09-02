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

import Foundation
@testable import GoogleCloudStorage
import Testing

@Suite struct FileSourceTests {
  /// Tests FileSource seeking to valid and invalid offsets.
  @Test func seek() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
    let fileURL = tempDirectory.appendingPathComponent("test_source_\(UUID().uuidString).txt")
    let data = Data(repeating: 65, count: 100)
    try data.write(to: fileURL)
    defer {
      try? FileManager.default.removeItem(at: fileURL)
    }

    var source = FileSource(fileURL: fileURL)
    #expect(source.totalSize == 100)

    // Seek to valid offset
    try await source.seek(to: 50)
    let chunk = try await source.read(maxBytes: 100)
    #expect(chunk?.count == 50)

    // Seek to negative offset
    let negativeErr = await expectError(UploadSourceError.self) {
      try await source.seek(to: -5)
    }
    if case .invalidSeekOffset(let offset) = negativeErr {
      #expect(offset == -5)
      #expect(negativeErr?.description == "invalidSeekOffset(-5)")
    } else {
      Issue.record("Expected .invalidSeekOffset, got \(String(describing: negativeErr))")
    }

    // Seek past end of file
    let pastEndErr = await expectError(UploadSourceError.self) {
      try await source.seek(to: 200)
    }
    if case .fileTooSmall(let fileSize, let offset) = pastEndErr {
      #expect(fileSize == 100)
      #expect(offset == 200)
      #expect(
        pastEndErr?.description
          == "fileTooSmall(fileSize: 100, offset: 200)")
    } else {
      Issue.record("Expected .fileTooSmall, got \(String(describing: pastEndErr))")
    }
  }

  /// Tests reading sequential chunks from a file.
  @Test func readChunks() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
    let fileURL = tempDirectory.appendingPathComponent("test_read_\(UUID().uuidString).txt")
    let testData = Data("Hello, World!".utf8)
    try testData.write(to: fileURL)
    defer {
      try? FileManager.default.removeItem(at: fileURL)
    }

    var source = FileSource(fileURL: fileURL)
    let first = try await source.read(maxBytes: 5)
    #expect(first == GoogleCloudStorage.ByteBuffer(Data("Hello".utf8)))

    let second = try await source.read(maxBytes: 100)
    #expect(second == GoogleCloudStorage.ByteBuffer(Data(", World!".utf8)))

    let third = try await source.read(maxBytes: 10)
    #expect(third == nil)
  }

  /// Tests that reading from a non-existent file throws `UploadSourceError`.
  @Test func readNonExistentFileThrowsUploadSourceError() async throws {
    let fileURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString).txt")
    var source = FileSource(fileURL: fileURL)

    let error = await expectError(UploadSourceError.self) {
      try await source.read(maxBytes: 100)
    }
    guard let error else {
      Issue.record("Expected UploadSourceError to be thrown")
      return
    }
    if case .readError(let underlying) = error {
      #expect(underlying is CocoaError)
    } else {
      Issue.record("Expected .readError, got \(String(describing: error))")
    }
  }
}
