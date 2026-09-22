// snippet.hide
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

// snippet.show
// snippet.imports [START swift_multiple_clients_imports]
import Foundation
import GoogleCloudSecretManagerV1
import GoogleCloudWorkflowsV1
// snippet.end [END swift_multiple_clients_imports]

// snippet.typealiases [START swift_multiple_clients_typealiases]
typealias SecretManagerServiceProtocol =
  GoogleCloudSecretManagerV1.Clients.SecretManagerServiceProtocol
typealias WorkflowsProtocol =
  GoogleCloudWorkflowsV1.Clients.WorkflowsProtocol
// snippet.end [END swift_multiple_clients_typealiases]

// snippet.function [START swift_multiple_clients_function]
func inspectProjectResources(
  projectId: String,
  region: String,
  secretManager: any SecretManagerServiceProtocol,
  workflows: any WorkflowsProtocol
) async throws {
  let secrets = try secretManager.listSecrets(
    byItem: ListSecretsRequest().with {
      $0.parent = "projects/\(projectId)"
    }
  )
  for try await secret in secrets {
    print("Secret: \(secret.name)")
  }

  let workflowItems = try workflows.listWorkflows(
    byItem: ListWorkflowsRequest().with {
      $0.parent = "projects/\(projectId)/locations/\(region)"
    }
  )
  for try await workflow in workflowItems {
    print("Workflow: \(workflow.name)")
  }
}
// snippet.end [END swift_multiple_clients_function]

// snippet.clients [START swift_multiple_clients_init]
func sample(projectId: String, region: String) async throws {
  let secretManagerClient = try SecretManagerServiceClient()
  let workflowsClient = try WorkflowsClient()

  try await inspectProjectResources(
    projectId: projectId,
    region: region,
    secretManager: secretManagerClient,
    workflows: workflowsClient
  )
}
// snippet.end [END swift_multiple_clients_init]

// snippet.hide
@main struct SnippetRunner {
  static func main() async throws {
    try await sample(projectId: "[placeholder]", region: "us-central1")
  }
}
