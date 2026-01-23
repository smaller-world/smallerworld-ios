import Foundation

struct SmallerWorld {
    #if DEBUG
        static let domain = "kaibook.itskai.me"
    #else
        static let domain = "smallerworld.club"
    #endif

    static let baseURL = URL(string: "https://\(domain)")!
    static let pathConfigurationURL = URL(
        string: "/path_configurations/ios_v1.json",
        relativeTo: baseURL
    )!
}
