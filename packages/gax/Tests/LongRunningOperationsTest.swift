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
import Testing

@testable import GoogleCloudGax

@Suite struct PollableOperationTest {
  struct MockError: Error, Equatable {
    var message: String
  }

  class MockPoller<ResponseType> {
    public var responses: [_PollableOperationImpl<ResponseType>.State] = []
    public var pollCount = 0

    public func poll() async throws -> _PollableOperationImpl<ResponseType>.State {
      defer { pollCount += 1 }
      return responses[pollCount]
    }
  }

  class MockSleeper {
    public var sleepCount = 0

    public func sleep(_: Duration) async throws {
      sleepCount = sleepCount + 1
    }
  }

  @Test func initialSuccess() async throws {
    let state = _PollableOperationImpl<String>.State(done: true, result: .success("success"))
    let op: any PollableOperation<String> = _PollableOperationImpl(initialState: state) {
      return state
    }
    let res = try await op.wait()
    #expect(res == "success")
  }

  @Test func initialFailure() async throws {
    let state = _PollableOperationImpl<String>.State(
      done: true, result: .failure(MockError(message: "error")))
    let op = _PollableOperationImpl(initialState: state) {
      return state
    }
    await #expect(throws: MockError(message: "error")) {
      try await op.wait()
    }
  }

  @Test func missingResult() async throws {
    let state = _PollableOperationImpl<String>.State(done: true, result: nil)
    let op = _PollableOperationImpl<String>(initialState: state) {
      return state
    }
    await #expect(
      throws: RequestError.malformedResponse("Operation completed but result was missing")
    ) {
      try await op.wait()
    }
  }

  @Test func waitLoopsUntilDone() async throws {
    let results = [
      _PollableOperationImpl<String>.State(done: false, result: nil),
      _PollableOperationImpl<String>.State(done: true, result: .success("polling success")),
    ]
    let pollProvider = MockPoller<String>()
    pollProvider.responses = results
    let sleepProvider = MockSleeper()
    let op = _PollableOperationImpl<String>(
      initialState: _PollableOperationImpl<String>.State(done: false, result: nil),
      poll: pollProvider.poll, sleep: sleepProvider.sleep)

    let res = try await op.wait()
    #expect(res == "polling success")
    #expect(pollProvider.pollCount == 2)
    #expect(sleepProvider.sleepCount == 2)
  }

  @Test func waitLoopsFailure() async throws {
    let results = [
      _PollableOperationImpl<String>.State(done: false, result: nil),
      _PollableOperationImpl<String>.State(done: false, result: nil),
      _PollableOperationImpl<String>.State(
        done: true, result: .failure(MockError(message: "intermediate error"))),
    ]
    let pollProvider = MockPoller<String>()
    pollProvider.responses = results
    let sleepProvider = MockSleeper()
    let op = _PollableOperationImpl<String>(
      initialState: _PollableOperationImpl<String>.State(done: false, result: nil),
      poll: pollProvider.poll, sleep: sleepProvider.sleep)

    await #expect(throws: MockError(message: "intermediate error")) {
      try await op.wait()
    }
    #expect(pollProvider.pollCount == 3)
    #expect(sleepProvider.sleepCount == 3)
  }

  @Test func waitLoopsPollThrows() async throws {
    let sleepProvider = MockSleeper()
    var pollCount = 0
    let op = _PollableOperationImpl<String>(
      initialState: _PollableOperationImpl<String>.State(done: false, result: nil),
      poll: {
        pollCount += 1
        throw RequestError.http(HTTPDetails(http_status_code: 404, headers: [:]))
      },
      sleep: sleepProvider.sleep
    )

    await #expect(throws: RequestError.self) {
      try await op.wait()
    }
    #expect(pollCount == 1)
    #expect(sleepProvider.sleepCount == 1)
  }

  @Test func voidOperationPolling() async throws {
    let results = [
      _PollableOperationImpl<Void>.State(done: false, result: nil),
      _PollableOperationImpl<Void>.State(done: true, result: .success(())),
    ]
    let pollProvider = MockPoller<Void>()
    pollProvider.responses = results
    let sleepProvider = MockSleeper()
    let op = _PollableOperationImpl<Void>(
      initialState: _PollableOperationImpl<Void>.State(done: false, result: nil),
      poll: pollProvider.poll, sleep: sleepProvider.sleep)

    try await op.wait()
    #expect(pollProvider.pollCount == 2)
    #expect(sleepProvider.sleepCount == 2)
  }
}
