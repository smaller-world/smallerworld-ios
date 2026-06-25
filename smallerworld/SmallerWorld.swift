import Foundation

struct SmallerWorld {
    #if DEBUG
        static let domain = "kaibook.itskai.me"
        static let altDomain = domain
    #else
        static let domain = "app.smallerworld.club"
        static let altDomain = "smlr.world"
    #endif

    static let baseURL = URL(string: "https://\(domain)")!
    static let homeURL = baseURL.appendingPathComponent("home")
    static let pathConfigurationURL = URL(
        string: "/path_configurations/ios_v1.json",
        relativeTo: baseURL
    )!
    static let userAgentPrefix: String = {
        ProcessInfo.processInfo.isiOSAppOnMac
            ? "SmallerWorldIosAppOnMac"
            : "SmallerWorldIos"
    }()
    
    static func url(forPath path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    static func isAppURL(_ url: URL) -> Bool {
        return url.host == domain || url.host == altDomain && url.path != "/"
    }
}
