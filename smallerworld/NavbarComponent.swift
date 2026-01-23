import HotwireNative
import UIKit

struct NavbarProps: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let title: String
        let icon: String?  // optional, SF Symbol name
    }
}

@MainActor
final class NavbarComponent: BridgeComponent {
    //    override class var name: String { "navbar" }

    //    @Published var props = NavbarProps(items: [])
    //
    //    func update(with props: NavbarMenuProps) {
    //        self.props = props
    //    }
}
