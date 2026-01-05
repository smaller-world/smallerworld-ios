import Foundation
import KeychainSwift
import WebKit

final class InstallationID {
  static let current = InstallationID()
  private let cookie_name = "installation_id"

  //  private let keychain = KeychainSwift()

  private init() {}

  func get() -> String {
    UIDevice.current.identifierForVendor!.uuidString
  }

  func setCookie(webView: WKWebView) {
    let components = URLComponents(url: AppDelegate.rootURL, resolvingAgainstBaseURL: false)!
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
    webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
  }
}
