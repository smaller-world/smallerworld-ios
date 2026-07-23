import Foundation
import Testing

@testable import smallerworld

struct smallerworldTests {

    // MARK: canonicalURL

    //    @Test("canonicalURL rewrites in-app hosts to the base host, preserving path/query/fragment")
    //    func testCanonicalURL() {
    //        let base = SmallerWorld.baseURL.host
    //
    //        // Alternate in-app host is rewritten to the canonical base host.
    //        let altHost = URL(string: "https://\(SmallerWorld.altDomain)/worlds/jordana?invite=xyz#top")!
    //        let canonical = SmallerWorld.canonicalURL(for: altHost)
    //        #expect(canonical.host == base)
    //        #expect(canonical.path == "/worlds/jordana")
    //        #expect(canonical.query == "invite=xyz")
    //        #expect(canonical.fragment == "top")
    //
    //        // External URLs pass through untouched.
    //        let external = URL(string: "https://example.com/foo?a=1")!
    //        #expect(SmallerWorld.canonicalURL(for: external) == external)
    //    }

}
