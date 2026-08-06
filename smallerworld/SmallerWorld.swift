import Foundation

enum SmallerWorld {
    static var domain: String {
        #if DEBUG
            "kaibook.itskai.me"
        #else
            "smallerworld.club"
        #endif
    }

    static var altDomain: String {
        #if DEBUG
            domain
        #else
            "smlr.world"
        #endif
    }

    static var baseURL: URL {
        URL(string: "https://\(domain)")!
    }

    static var homeURL: URL {
        baseURL.appendingPathComponent("home")
    }

    static var pathConfigurationURL: URL {
        URL(
            string: "/path_configurations/ios_v1.json",
            relativeTo: baseURL
        )!
    }

    static var userAgentPrefix: String {
        ProcessInfo.processInfo.isiOSAppOnMac
            ? "SmallerWorldIosAppOnMac;"
            : "SmallerWorldIos;"
    }

    // MARK: Helpers

    static func url(forPath path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    static func isAppURL(_ url: URL) -> Bool {
        return (url.host == domain || url.host == altDomain) && url.path != "/"
    }

    /// Rewrites an in-app `url` so its scheme/host match `baseURL`, preserving
    /// path/query/fragment. External URLs pass through untouched.
    static func canonicalURL(for url: URL) -> URL {
        guard isAppURL(url) else { return url }
        guard
            var components = URLComponents(
                url: baseURL,
                resolvingAgainstBaseURL: true
            )
        else {
            return url
        }
        components.path = url.path
        components.query = url.query(percentEncoded: false)
        components.fragment = url.fragment
        return components.url ?? url
    }
}
