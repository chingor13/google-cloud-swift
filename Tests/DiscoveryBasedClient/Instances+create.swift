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

// [START compute_instances_create]
import GoogleCloudComputeV1
import GoogleCloudGax
import Logging

extension InstanceSamples {
  static public func create(
    client: some GoogleCloudComputeV1.Instances,
    projectId: String,
    zoneId: String,
    name: String,
    logger: Logger
  ) async throws {
    logger.info("Calling Instances::insert()")
    let bootDisk = AttachedDisk().with {
      $0.initializeParams = AttachedDiskInitializeParams().with {
        $0.sourceImage = "projects/cos-cloud/global/images/family/cos-stable"
      }
      $0.boot = true
      $0.autoDelete = true
    }
    let nic = NetworkInterface().with {
      $0.network = "global/networks/default"
    }
    let instance = Instance().with {
      $0.machineType = "zones/\(zoneId)/machineTypes/f1-micro"
      $0.name = name
      $0.description = "A test VM created by the Swift client library."
      $0.labels = ["source": "compute_instances_create"]
      $0.disks = [bootDisk]
      $0.networkInterfaces = [nic]
    }
    var operation = try await client.insert(
      request: Clients.InstancesClient.InsertRequest().with {
        $0.project = projectId
        $0.zone = zoneId
        $0.body = instance
      })
    guard let operationName = operation.name else {
      throw GoogleCloudGax.RequestError.malformedResponse("missing operation name")
    }
    let poller = try GoogleCloudComputeV1.Clients.ZoneOperationsClient()
    for _ in 0...10 {
      operation = try await poller.get(project: projectId, zone: zoneId, operation: operationName)
      if let status = operation.status, status == .done {
        break
      }
      logger.info("backoff")
      try await Task.sleep(for: .seconds(1))
    }
    logger.info("Instance.insert() completed successfully")
  }
}
// [END compute_instances_create]
