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

@Suite struct UploadSourceErrorTests {
  struct TestError: Error, CustomStringConvertible {
    var description: String { "test error description" }
  }

  @Test func testReadErrorFactoryAndPatternMatching() {
    let underlying = TestError()
    let error = UploadSourceError.readError(underlying)

    guard case .readError(let caught) = error else {
      Issue.record("Expected .readError, got \(error)")
      return
    }
    #expect(caught is TestError)
    #expect(error.description == "readError(test error description)")
  }

  @Test func testInvalidSeekOffset() {
    let error = UploadSourceError.invalidSeekOffset(-10)
    guard case .invalidSeekOffset(let offset) = error else {
      Issue.record("Expected .invalidSeekOffset, got \(error)")
      return
    }
    #expect(offset == -10)
    #expect(error.description == "invalidSeekOffset(-10)")
  }

  @Test func testSourceTooSmall() {
    let error = UploadSourceError.sourceTooSmall(size: 10, offset: 20)
    guard case .sourceTooSmall(let size, let offset) = error else {
      Issue.record("Expected .sourceTooSmall, got \(error)")
      return
    }
    #expect(size == 10)
    #expect(offset == 20)
    #expect(error.description == "sourceTooSmall(size: 10, offset: 20)")
  }
}
