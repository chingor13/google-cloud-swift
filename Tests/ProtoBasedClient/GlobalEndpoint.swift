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

import GoogleCloudLocation
import GoogleCloudSecretmanagerV1
import GoogleCloudWkt
import GoogleIamV1
import CryptoSwift

/// Run tests for the global endpoint.
public enum GlobalEndpoint {
  static public func run() async throws {
    let projectId = try projectId()
    let secretId = randomSecretId()
    let client = try GoogleCloudSecretmanagerV1.Clients.SecretManagerServiceClient()

    print("Testing createSecret()")
    let create = try await client.createSecret(
      request: CreateSecretRequest(
        parent: "projects/\(projectId)", secretId: secretId,
        secret: Secret(
          replication: Replication(replication: .automatic(Replication.Automatic())),
          labels: ["integration-test": "true"])
      ))
    print("create = \(create)")

    print("\nTesting getSecret()")
    let get = try await client.getSecret(request: GetSecretRequest(name: create.name))
    print("get = \(get)")

    try await testSecretVersions(client: client, secretName: create.name)
    try await testIAM(client: client, secretName: create.name)
    try await testLocations(client: client, projectId: projectId)

    print("\nTesting updateSecret()")
    var updatedLabels = get.labels
    updatedLabels["updated"] = "test-1"
    var updatedAnnotations = get.annotations
    updatedAnnotations["updated"] = "test-1"

    let update = try await client.updateSecret(
      request: UpdateSecretRequest(
        secret: Secret(
          name: create.name,
          labels: updatedLabels,
          etag: get.etag,
          versionAliases: ["test-alias": Int64(1)],
          annotations: updatedAnnotations),
        updateMask: GoogleCloudWkt.FieldMask(paths: ["annotations", "labels", "versionAliases"])
      ),
    )
    print("update = \(update)")

    print("\nTesting listSecrets()")
    let page = try await client.listSecrets(
      request: ListSecretsRequest(parent: "projects/\(projectId)"))
    print("page count = \(page.secrets.count)")

    print("\nTesting deleteSecret()")
    try await client.deleteSecret(request: DeleteSecretRequest(name: get.name))
    print("deleteSecret() was successful")
  }

  static private func testSecretVersions(client: SecretManagerService, secretName: String)
    async throws
  {
    print("\nTesting secret version CRUD")
    let data = "the quick brown fox jumps over the lazy dog".data(using: .utf8)!
    let checksum = CryptoSwift.Checksum.crc32c(data.byteArray)
    let version = try await client.addSecretVersion(
      request: AddSecretVersionRequest(
        parent: secretName,
        payload: SecretPayload(
          data: data,
          dataCrc32C: Int64(checksum),
        )))
    print("version = \(version)")

    print("\nTesting getSecretVersion()")
    let getVersion = try await client.getSecretVersion(
      request: GetSecretVersionRequest(name: version.name))
    print("getVersion = \(getVersion)")

    print("\nTesting accessSecretVersion()")
    let accessVersion = try await client.accessSecretVersion(
      request: AccessSecretVersionRequest(name: version.name))
    print("accessVersion payload length = \(accessVersion.payload?.data.count ?? 0)")

    print("\nTesting disableSecretVersion()")
    let disabledVersion = try await client.disableSecretVersion(
      request: DisableSecretVersionRequest(name: version.name))
    print("disabledVersion state = \(disabledVersion.state)")

    print("\nTesting enableSecretVersion()")
    let enabledVersion = try await client.enableSecretVersion(
      request: EnableSecretVersionRequest(name: version.name))
    print("enabledVersion state = \(enabledVersion.state)")

    print("\nTesting listSecretVersions()")
    let versionsPage = try await client.listSecretVersions(
      request: ListSecretVersionsRequest(parent: secretName))
    print("versionsPage count = \(versionsPage.versions.count)")

    print("\nTesting destroySecretVersion()")
    let destroyedVersion = try await client.destroySecretVersion(
      request: DestroySecretVersionRequest(name: version.name))
    print("destroyedVersion state = \(destroyedVersion.state)")
  }

  static private func testIAM(client: SecretManagerService, secretName: String) async throws {
    print("\nTesting IAM operations")
    let serviceAccount = try testServiceAccount();
    print("Testing getIamPolicy()")
    var policy = try await client.getIamPolicy(request: GetIamPolicyRequest(resource: secretName))
    print("policy = \(policy)")

    print("Testing testIamPermissions()")
    let permissions = try await client.testIamPermissions(
      request: TestIamPermissionsRequest(
        resource: secretName,
        permissions: ["secretmanager.versions.access"]))
    print("permissions = \(permissions)")

    print("Testing setIamPolicy()")
    let role = "roles/secretmanager.secretVersionAdder"
    if var found = policy.bindings.first(where: { $0.role == role }) {
      found.members.append("serviceAccount:\(serviceAccount)")
    } else {
      policy.bindings.append(Binding(role: role, members: ["serviceAccount:\(serviceAccount)"]))
    }
    let updatedPolicy = try await client.setIamPolicy(
      request: SetIamPolicyRequest(resource: secretName, policy: policy))
    print("updatedPolicy = \(updatedPolicy)")
  }

  static private func testLocations(client: SecretManagerService, projectId: String) async throws {
    print("\nTesting location operations")
    print("Testing listLocations()")
    let locations = try await client.listLocations(
      request: ListLocationsRequest(name: "projects/\(projectId)"))
    print("locations count = \(locations.locations.count)")

    if let firstLocation = locations.locations.first {
      print("Testing getLocation() for \(firstLocation.name)")
      let location = try await client.getLocation(
        request: GetLocationRequest(name: firstLocation.name))
      print("location = \(location)")
    }
  }
}
