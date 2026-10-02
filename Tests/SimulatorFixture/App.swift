import Foundation
import SwiftUI

@main
struct RoamerTestApp: App {
    var body: some Scene {
        WindowGroup { ProbeView() }
            .defaultSize(width: 1100, height: 950)
    }
}

private enum Page: String, CaseIterable {
    case interaction = "Interaction"
    case keys = "Key events"
    case rawKeys = "Raw key codes"
}

private struct ProbeView: View {
    @State private var page: Page = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--keys") { return .keys }
        if arguments.contains("--raw-keys") { return .rawKeys }
        return .interaction
    }()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(Page.allCases, id: \.self) { candidate in
                    Button(candidate.rawValue) { page = candidate }
                        .tint(page == candidate ? .blue : .gray)
                }
            }
            switch page {
            case .interaction: InteractionView()
            case .keys: KeyEventsView()
            case .rawKeys: RawKeysView().frame(width: 1000, height: 740)
            }
        }
        .padding(24)
    }
}
