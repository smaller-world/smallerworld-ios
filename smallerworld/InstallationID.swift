import Foundation
import KeychainSwift
import WebKit

final class InstallationID {
  static let shared = InstallationID()
  private let cookie_name = "installation_id"

  //  private let keychain = KeychainSwift()

  private init() {}

  func get() async -> String {
    let sleepNanos = UInt64(1_000_000_000)
    while true {
      if let id = UIDevice.current.identifierForVendor?.uuidString {
        return id
      }
      try? await Task.sleep(nanoseconds: sleepNanos)
    }
  }

  func setDefaultCookie() async {
    let components = URLComponents(url: AppConstants.rootURL, resolvingAgainstBaseURL: true)!
    var properties: [HTTPCookiePropertyKey: Any] = [
      .name: cookie_name,
      .value: await get(),
      .domain: components.host!,
      .path: "/",  // A path of "/" makes it available to all paths on the domain
      .secure: components.scheme == "https",
    ]
    if let port = components.port {
      properties[.port] = port
    }
    let cookie = HTTPCookie(properties: properties)!
    await withCheckedContinuation { continuation in
      WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) {
        continuation.resume()
      }
    }
  }
}
