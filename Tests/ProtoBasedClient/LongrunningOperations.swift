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
import GoogleCloudWkt
import GoogleCloudWorkflowsV1

/// Run tests for LROs.
public enum LongrunningOperations {
  static public func run() async throws {
    let projectId = try #require(
      ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"],
      "GOOGLE_CLOUD_PROJECT environment variable must be set")

    try await createAndDeleteWorkflow(projectId: projectId)
  }

  static private func createAndDeleteWorkflow(projectId: String) async throws {
    let client = try GoogleCloudWorkflowsV1.Clients.WorkflowsClient()
    let workflowId =
      "test_wf_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_").prefix(20))"
    let parent = "projects/\(projectId)/locations/us-central1"

    print("Testing createWorkflow()")
    let create = CreateWorkflowRequest(
      parent: parent,
      workflow: Workflow(
        description: "Test workflow created by integration test",
        sourceCode: .sourceContents(
          """
          - init:
              assign:
                - message: "Hello World"
          - finish:
              return: ${message}
          """)
      ),
      workflowId: workflowId
    )
    print("create = \(create)")

    let createLro = try await client.createWorkflow(withPolling: create)
    let workflow = try await createLro.wait()
    print("createWorkflow() was successful")
    #expect(workflow.name == "\(parent)/workflows/\(workflowId)")

    print("\nTesting deleteWorkflow() for \(workflow.name)")
    let deleteLro = try await client.deleteWorkflow(
      withPolling: DeleteWorkflowRequest(name: workflow.name))
    _ = try await deleteLro.wait()
    print("deleteWorkflow() was successful")
  }
}
