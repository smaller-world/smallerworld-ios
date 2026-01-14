import Foundation
@MainActor
final class NavigationTracker {
  public private(set) var isNavigating = false
  private var waiters: [CheckedContinuation<Bool, Never>] = []

  func waitForCurrentRequestToFinish() async -> Bool {
    if !isNavigating {
      return true
    }
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  func visitStarted() {
    isNavigating = true
  }

  func visitEnded(success: Bool = true) {
    isNavigating = false
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations {
      continuation.resume(returning: success)
    }
  }
}
