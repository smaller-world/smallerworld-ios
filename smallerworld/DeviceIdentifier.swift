import Foundation
import WebKit
import os

final class DeviceIdentifier {
    static let shared = DeviceIdentifier()
    private let cookieName = "device_identifier"

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
        let identifier = await get()
        Log.app.info(
            "Set \(self.cookieName, privacy: .public) cookie to: \(identifier, privacy: .private(mask: .hash))"
        )
        let components = URLComponents(
            url: SmallerWorld.baseURL,
            resolvingAgainstBaseURL: true
        )!
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: cookieName,
            .value: identifier,
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
