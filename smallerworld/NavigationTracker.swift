import Foundation
import os

@MainActor
final class NavigationTracker: CustomStringConvertible {
  public private(set) var isNavigating = false
  public private(set) var lastNavigationSuccess = false
  
  private var name: String
  private var waiters: [CheckedContinuation<Bool, Never>] = []
  
  init(name: String) {
    self.name = name
  }

  func waitForCurrentRequestToFinish() async -> Bool {
    if !isNavigating {
      return true
    }
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  func visitStarted() {
    log("visitStarted")
    isNavigating = true
  }

  func visitEnded(success: Bool = true) {
    log("visitEnded", ["success": success])
    isNavigating = false
    lastNavigationSuccess = success
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations {
      continuation.resume(returning: success)
    }
  }
  
  private func log(_ name: String, _ arguments: [String: Any] = [:]) {
    logger.debug("[NavigationTracker: \(self.name)] \(name) \(arguments)")
  }

  var description: String {
    "NavigationTracker(isNavigating: \(isNavigating), lastNavigationSuccess: \(lastNavigationSuccess))"
  }
}
