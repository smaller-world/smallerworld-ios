import Foundation
import KeychainSwift
import WebKit

final class InstallationID {
  static let shared = InstallationID()
  private let cookie_name = "installation_id"

  //  private let keychain = KeychainSwift()

  private init() {}

  func get() -> String {
    UIDevice.current.identifierForVendor?.uuidString ?? ""
  }

  func setDefaultCookie(completionHandler: (() -> Void)? = nil) {
    let components = URLComponents(url: AppConstants.rootURL, resolvingAgainstBaseURL: true)!
    var properties: [HTTPCookiePropertyKey: Any] = [
      .name: cookie_name,
      .value: get(),
      .domain: components.host!,
      .path: "/",  // A path of "/" makes it available to all paths on the domain
      .secure: components.scheme == "https",
    ]
    if let port = components.port {
      properties[.port] = port
    }
    let cookie = HTTPCookie(properties: properties)!
    WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie, completionHandler: completionHandler)
  }
}
