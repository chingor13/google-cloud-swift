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

/// A protocol for observing lifecycle, progress, and resilience events during Cloud Storage uploads.
public protocol UploadObserver: OperationObserver
where Context == StorageOperationContext, Progress == UploadProgress, Result == Object {}

/// Composite observer that dispatches events to multiple upload observers.
package struct _CompositeUploadObserver: UploadObserver, Sendable {
  package let observers: [any UploadObserver]

  package init(_ observers: [any UploadObserver]) {
    self.observers = observers
  }

  package func operationDidStart(context: StorageOperationContext) {
    for observer in observers {
      observer.operationDidStart(context: context)
    }
  }

  package func progressUpdated(_ progress: UploadProgress) {
    for observer in observers {
      observer.progressUpdated(progress)
    }
  }

  package func operationDidRetry(_ retry: RetryDetails) {
    for observer in observers {
      observer.operationDidRetry(retry)
    }
  }

  package func operationDidComplete(result: Object, totalDuration: Duration) {
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
