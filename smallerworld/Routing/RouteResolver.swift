import Foundation
import HotwireNative
import os

/// Pure routing math over URLs and the Hotwire path configuration.
///
/// Caseless namespace — these functions have no state and only read the
/// global `Hotwire.config.pathConfiguration`, so there is nothing to
/// instantiate. Kept free of any scene/navigator state so the tricky
/// segment/next-hop logic can be unit-tested in isolation.
enum RouteResolver {
    /// Returns the cumulative path at each routable depth along `url`,
    /// skipping any depth whose cumulative path is marked `"unroutable": true`
    /// in the path configuration. `nil` and any URL whose path resolves to
    /// `"presentation": "replace_root"` (e.g. `/home`, `/session/new`) both
    /// return `[]` — these collapse to the nav root.
    ///
    /// Examples (with `/worlds` and `/world_key_grants` marked unroutable):
    /// - nil                            => []
    /// - /home                          => []
    /// - /worlds/asdf-12-23             => ["/worlds/asdf-12-23"]
    /// - /worlds/asdf-12-23/keys        => ["/worlds/asdf-12-23", "/worlds/asdf-12-23/keys"]
    /// - /world_key_grants/TOKEN        => ["/world_key_grants/TOKEN"]
    /// - /worlds                        => ["/worlds"] (unroutable but nowhere to escalate to)
    static func segments(of url: URL?) -> [String] {
        guard let url else { return [] }
        if isRootPath(url) { return [] }
        let raw = url.pathComponents.filter { $0 != "/" }
        var result: [String] = []
        var current = ""
        for component in raw {
            current += "/" + component
            if !isUnroutablePath(current) {
                result.append(current)
            }
        }
        // Fall back to the raw path when every depth was unroutable — callers
        // still need something to land on.
        if result.isEmpty, !current.isEmpty {
            result.append(current)
        }
        return result
    }

    static func isRootPath(_ url: URL) -> Bool {
        let properties = Hotwire.config.pathConfiguration.properties(for: url)
        return properties["presentation"] as? String == "replace_root"
    }

    /// Returns the next URL to land on while routing from `from` toward `to`.
    /// The caller decides whether to push or pop based on whether the returned
    /// URL is already present in the navigation stack.
    ///
    /// Examples (with /home as root, /worlds unroutable):
    /// - from: /worlds/jordana        to: /home                => /home
    /// - from: /worlds/jordana        to: /worlds/freddy       => /home
    /// - from: /worlds/jordana/keys   to: /worlds/jordana      => /worlds/jordana
    /// - from: /home                  to: /worlds/jordana      => /worlds/jordana
    /// - from: /worlds/freddy         to: /worlds/freddy/keys  => /worlds/freddy/keys
    static func nextURL(from: URL?, to: URL) -> URL {
        let fromSegs = segments(of: from)
        let toSegs = segments(of: to)

        var prefixCount = 0
        let maxPrefix = min(fromSegs.count, toSegs.count)
        while prefixCount < maxPrefix && fromSegs[prefixCount] == toSegs[prefixCount] {
            prefixCount += 1
        }

        if prefixCount == fromSegs.count {
            // Advancing toward `to` (or already there).
            if prefixCount == toSegs.count { return to }
            return SmallerWorld.url(forPath: toSegs[prefixCount])
        }

        // Retreating to the deepest shared ancestor.
        if prefixCount == 0 {
            return SmallerWorld.homeURL
        }

        return SmallerWorld.url(forPath: toSegs[prefixCount - 1])
    }
    
    // MARK: Helpers
    
    private static func isUnroutablePath(_ path: String) -> Bool {
        let properties = Hotwire.config.pathConfiguration.properties(for: path)
        return properties["unroutable"] as? Bool ?? false
    }
}
