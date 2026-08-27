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

/// A protocol for observing lifecycle, progress, and resilience events during Cloud Storage downloads.
public protocol DownloadObserver: OperationObserver
where Context == StorageOperationContext, Progress == DownloadProgress, Result == ReadObjectMetadata
{}

/// Composite observer that dispatches events to multiple download observers.
package struct _CompositeDownloadObserver: DownloadObserver, Sendable {
  package let observers: [any DownloadObserver]

  package init(_ observers: [any DownloadObserver]) {
    self.observers = observers
  }

  package func operationDidStart(context: StorageOperationContext) {
    for observer in observers {
      observer.operationDidStart(context: context)
    }
  }

  package func progressUpdated(_ progress: DownloadProgress) {
    for observer in observers {
      observer.progressUpdated(progress)
    }
  }

  package func operationDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    for observer in observers {
      observer.operationDidRetry(attempt: attempt, error: error, backoff: backoff)
    }
  }

  package func operationDidComplete(result: ReadObjectMetadata, totalDuration: Duration) {
    for observer in observers {
      observer.operationDidComplete(result: result, totalDuration: totalDuration)
    }
  }

  package func operationDidFail(error: any Error) {
    for observer in observers {
      observer.operationDidFail(error: error)
    }
  }
}
