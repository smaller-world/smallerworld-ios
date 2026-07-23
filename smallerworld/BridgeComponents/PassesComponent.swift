import Foundation
import HotwireNative
import PassKit
import UIKit
import os

final class PassesComponent: BridgeComponent {
    override nonisolated class var name: String { "passes" }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .connect:
            handleConnect()
        }
    }

    private func handleConnect() {
        let passes = Self.loadPasses()
        let data = ConnectReplyData(passes: passes)
        reply(to: Event.connect.rawValue, with: data)
    }

    @MainActor
    private static func loadPasses() -> [PassData] {
        let library = PKPassLibrary()
        return library.passes().map(PassData.init(pass:))
    }
}

extension PassesComponent {
    fileprivate enum Event: String {
        case connect
    }

    fileprivate struct ConnectReplyData: Encodable, Sendable {
        let passes: [PassData]
    }

    fileprivate struct PassData: Encodable, Sendable {
        let passTypeIdentifier: String
        let serialNumber: String

        init(pass: PKPass) {
            self.passTypeIdentifier = pass.passTypeIdentifier
            self.serialNumber = pass.serialNumber
        }
    }
}
