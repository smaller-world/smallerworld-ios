import HotwireNative
import Foundation

@MainActor
final class SceneNavigatorDelegate: NSObject, NavigatorDelegate {
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

  func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
    isNavigating = true
    return .accept
  }

  func requestDidFinish(at url: URL) {
    resolve(success: true)
  }

  func visitableDidFailRequest(
    _ visitable: Visitable,
    error: Error,
    retryHandler: @escaping RetryBlock
  ) {
    resolve(success: false)
  }

  private func resolve(success: Bool) {
    isNavigating = false
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations {
      continuation.resume(returning: success)
    }
  }
}
