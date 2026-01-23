import HotwireNative
import UIKit

extension HotwireTab {
    static let all: [HotwireTab] = [.world, .universe, .spaces]
    static let byID: [String: HotwireTab] = [
        "world": .world,
        "universe": .universe,
        "spaces": .spaces,
    ]

    static let world = HotwireTab(
        title: "your world",
        image: UIImage(systemName: "person.crop.square.fill")!,
        url: SmallerWorld.baseURL.appendingPathComponent("/world")
    )

    static let universe = HotwireTab(
        title: "universe",
        image: UIImage(systemName: "square.grid.2x2.fill")!,
        url: SmallerWorld.baseURL.appendingPathComponent("/universe")
    )

    static let spaces = HotwireTab(
        title: "spaces",
        image: UIImage(systemName: "person.2.crop.square.stack.fill")!,
        url: SmallerWorld.baseURL.appendingPathComponent("/spaces")
    )

    /// Get the tab that should handle a given URL based on path prefix.
    static func targetTab(for url: URL) -> HotwireTab? {
        if isPathOrHasPrefix(url.path, target: "/world") {
            return .world
        }
        if isPathOrHasPrefix(url.path, target: "/universe") {
            return .universe
        }
        if isPathOrHasPrefix(url.path, target: "/spaces") {
            return .spaces
        }
        if let tabID = requestedTabID(url), let tab = byID[tabID] {
            return tab
        }
        return nil
    }

    private static func isPathOrHasPrefix(_ path: String, target: String) -> Bool {
        if path == target {
            return true
        }
        return path.hasPrefix(target + "/")
    }

    private static func requestedTabID(_ url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        let item = components.queryItems?.first { queryItem in
            queryItem.name == "native_tab"
        }
        return item?.value
    }
}
