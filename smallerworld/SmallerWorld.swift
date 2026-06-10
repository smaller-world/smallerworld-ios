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

    // Paths that are not directly routable on their own — when splitting a URL
    // into route segments, a path here is merged with its following segment
    // (e.g. "/worlds/asdf-12" becomes one segment, not two).
    static let unroutablePaths: Set<String> = ["/worlds"]

    static func isAppURL(_ url: URL) -> Bool {
        return url.host == domain || url.host == altDomain && url.path != "/"
    }
}
