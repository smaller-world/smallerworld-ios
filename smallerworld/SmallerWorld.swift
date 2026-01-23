import Foundation

struct SmallerWorld {
    #if DEBUG
        static let domain = "kaibook.itskai.me"
        static let altDomain = "localhost"
    #else
        static let domain = "smallerworld.club"
        static let altDomain = "smlr.world"
    #endif

    static let baseURL = URL(string: "https://\(domain)")!
    static let pathConfigurationURL = URL(
        string: "/path_configurations/ios_v1.json",
        relativeTo: baseURL
    )!

    static func isAppURL(_ url: URL) -> Bool {
        return url.host == domain || url.host == altDomain && url.path != "/"
    }
}
