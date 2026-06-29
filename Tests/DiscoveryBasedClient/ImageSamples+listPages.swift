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

// [START compute_images_list_pages]
import GoogleCloudComputeV1
import Logging

extension ImageSamples {
  static public func listPages(
    client: some GoogleCloudComputeV1.Images, projectId: String, logger: Logger
  ) async throws {
    logger.info("Calling listImages()")
    var request = GoogleCloudComputeV1.Clients.ImagesClient.ListRequest().with {
      $0.project = projectId
      // Return at most 100 items per response (page)
      $0.maxResults = 100
      // skip deprecated items.
      $0.filter = "deprecated.state != DEPRECATED"
    }

    while true {
      let response = try await client.list(request: request)
      for image in response.items {
        logger.info("  image = \(image)")
      }
      // Read the next page, if any.
      guard let nextPageToken = response.nextPageToken, !nextPageToken.isEmpty else {
        break
      }
      request.pageToken = nextPageToken
    }
    logger.info("listImages() completed successfully")
  }
}
// [END compute_images_list_pages]
