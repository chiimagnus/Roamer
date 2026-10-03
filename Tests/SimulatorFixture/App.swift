import Foundation
import SwiftUI

@main
struct RoamerTestApp: App {
    @State private var spatial = SpatialSceneState()

    var body: some Scene {
        WindowGroup { ProbeView(spatial: spatial) }
            .defaultSize(width: 1100, height: 950)
        ImmersiveSpace(id: "SpatialScene") { SpatialSceneView(state: spatial) }
            .immersionStyle(
                selection: .constant(.progressive(0.0...1.0, initialAmount: 0.5)),
                in: .progressive
            )
    }
}

private enum Page: String, CaseIterable {
    case interaction = "Interaction"
    case keys = "Key events"
    case rawKeys = "Raw key codes"
    case spatial = "Spatial scene"
}

private struct ProbeView: View {
    let spatial: SpatialSceneState

    @State private var page: Page = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--keys") { return .keys }
        if arguments.contains("--raw-keys") { return .rawKeys }
        if arguments.contains("--space") { return .spatial }
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
            case .spatial: SpatialSceneControls(state: spatial)
            }
        }
        .padding(24)
    }
}
