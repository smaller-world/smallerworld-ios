import Foundation
import Testing

@testable import smallerworld

struct NextURLTests {
    private static func url(_ path: String) -> URL {
        SmallerWorld.baseURL.appendingPathComponent(path)
    }

    // MARK: routeSegments

    @Test("routeSegments splits paths and merges unroutable prefixes")
    func routeSegmentsCases() {
        #expect(SceneController.routeSegments(of: nil) == [])
        #expect(SceneController.routeSegments(of: SmallerWorld.rootURL) == [])
        #expect(SceneController.routeSegments(of: Self.url("/home")) == [])
        #expect(
            SceneController.routeSegments(of: Self.url("/worlds/asdf-12-23"))
                == ["worlds/asdf-12-23"]
        )
        #expect(
            SceneController.routeSegments(of: Self.url("/worlds/asdf-12-23/keys"))
                == ["worlds/asdf-12-23", "keys"]
        )
        // Unroutable prefix with nothing after it falls back to the raw segment.
        #expect(SceneController.routeSegments(of: Self.url("/worlds")) == ["worlds"])
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
        ]
    )
    func nextURLCases(testCase: NextURLCase) {
        let from = testCase.from.map { Self.url($0) }
        let to = Self.url(testCase.to)
        let result = SceneController.nextURL(from: from, to: to)
        #expect(result.path == testCase.expected)
        #expect(result.host == SmallerWorld.baseURL.host)
    }
}
