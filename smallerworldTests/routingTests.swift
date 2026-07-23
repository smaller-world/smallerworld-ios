import Foundation
import Testing

@testable import smallerworld

struct routingTests {
    private static func url(_ path: String) -> URL {
        SmallerWorld.baseURL.appendingPathComponent(path)
    }

    // MARK: segments

    @Test("segments returns cumulative paths, skipping unroutable depths")
    func testSegments() {
        #expect(RouteResolver.segments(of: nil) == [])
        #expect(RouteResolver.segments(of: Self.url("/home")) == [])
        #expect(
            RouteResolver.segments(of: Self.url("/worlds/asdf-12-23"))
                == ["/worlds/asdf-12-23"]
        )
        #expect(
            RouteResolver.segments(of: Self.url("/worlds/asdf-12-23/keys"))
                == ["/worlds/asdf-12-23", "/worlds/asdf-12-23/keys"]
        )
        // Unroutable path with nothing routable to escalate to falls back
        // to the raw path so callers still have something to land on.
        #expect(RouteResolver.segments(of: Self.url("/worlds")) == ["/worlds"])
        // Other unroutable prefixes from the path configuration.
        #expect(
            RouteResolver.segments(of: Self.url("/world_key_grants/TOKEN"))
                == ["/world_key_grants/TOKEN"]
        )
        #expect(
            RouteResolver.segments(of: Self.url("/world_cards/abc-123"))
                == ["/world_cards/abc-123"]
        )
        // Trailing slash should not change the segments.
        #expect(
            RouteResolver.segments(of: Self.url("/worlds/asdf-12-23/"))
                == ["/worlds/asdf-12-23"]
        )
        // Query / fragment should not change the segments.
        #expect(
            RouteResolver.segments(
                of: URL(string: "/worlds/asdf-12-23?invite=xyz", relativeTo: SmallerWorld.baseURL)!
            ) == ["/worlds/asdf-12-23"]
        )
        #expect(
            RouteResolver.segments(
                of: URL(string: "/worlds/asdf-12-23#section", relativeTo: SmallerWorld.baseURL)!
            ) == ["/worlds/asdf-12-23"]
        )
        // Paths the config has no opinion on emit a cumulative path at every depth.
        #expect(
            RouteResolver.segments(of: Self.url("/unknown/abc-123"))
                == ["/unknown", "/unknown/abc-123"]
        )
    }

    // MARK: nextURL

    struct NextURLCase: CustomStringConvertible {
        let from: String?
        let to: String
        let expected: String
        var description: String { "from \(from ?? "nil") to \(to) => \(expected)" }
    }

    @Test(
        "nextURL advances toward to, or retreats to deepest shared ancestor",
        arguments: [
            // Retreat: no shared segments => /home (root).
            NextURLCase(from: "/worlds/jordana", to: "/home", expected: "/home"),
            NextURLCase(from: "/worlds/jordana", to: "/worlds/freddy", expected: "/home"),
            // Retreat: shared prefix of length 1 => /worlds/jordana.
            NextURLCase(
                from: "/worlds/jordana/keys",
                to: "/worlds/jordana",
                expected: "/worlds/jordana"
            ),
            // Advance: from is a prefix of to.
            NextURLCase(from: "/home", to: "/worlds/jordana", expected: "/worlds/jordana"),
            NextURLCase(
                from: "/worlds/freddy",
                to: "/worlds/freddy/keys",
                expected: "/worlds/freddy/keys"
            ),
            // Advance from nil (cold-start, no current URL) is equivalent to advance from root.
            NextURLCase(from: nil, to: "/worlds/jordana", expected: "/worlds/jordana"),
            // Already at to: returns to.
            NextURLCase(
                from: "/worlds/jordana",
                to: "/worlds/jordana",
                expected: "/worlds/jordana"
            ),
            // Deep cold-start ladder: advance one segment at a time toward a nested target.
            NextURLCase(from: nil, to: "/worlds/jordana/keys", expected: "/worlds/jordana"),
            NextURLCase(from: "/home", to: "/worlds/jordana/keys", expected: "/worlds/jordana"),
            NextURLCase(
                from: "/worlds/jordana",
                to: "/worlds/jordana/keys",
                expected: "/worlds/jordana/keys"
            ),
            // Cross-unroutable retreat: shared depth but different unroutable prefix => /home.
            NextURLCase(
                from: "/worlds/jordana/keys",
                to: "/worlds/freddy/keys",
                expected: "/home"
            ),
            // Other unroutable prefixes behave the same.
            NextURLCase(
                from: "/world_key_grants/T1",
                to: "/home",
                expected: "/home"
            ),
            NextURLCase(
                from: "/world_key_grants/T1",
                to: "/world_key_grants/T2",
                expected: "/home"
            ),
            NextURLCase(
                from: nil,
                to: "/world_key_grants/TOKEN",
                expected: "/world_key_grants/TOKEN"
            ),
            // Navigating to the unroutable root itself retreats to /home rather than
            // landing on a path that has no server route.
            NextURLCase(from: "/worlds/jordana", to: "/worlds", expected: "/home"),
        ]
    )
    func testNextUrl(testCase: NextURLCase) {
        let from = testCase.from.map { Self.url($0) }
        let to = Self.url(testCase.to)
        let result = RouteResolver.nextURL(from: from, to: to)
        #expect(result.path == testCase.expected)
        #expect(result.host == SmallerWorld.baseURL.host)
    }
}
