import RealityKit
import SwiftUI

struct SpatialSceneControls: View {
    let state: SpatialSceneState
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var transitioning = false

    var body: some View {
        VStack(spacing: 30) {
            Text("ROAMER SPATIAL SCENE").font(.title).bold()
            Text(state.status).font(.title2.monospaced())
            Text("Blue cuboid: click moves 0.1m in parent X; drag moves in 3D.")
            Text("Orange cuboid has no accessibility description. Green plane has zero thickness.")
            Button(state.isOpen ? "Close space" : "Open space") {
                transitioning = true
                Task {
                    if state.isOpen {
                        await dismissImmersiveSpace()
                    } else {
                        switch await openImmersiveSpace(id: "SpatialScene") {
                        case .opened: break
                        case .userCancelled: state.status = "Opening cancelled"
                        case .error: state.status = "Opening failed"
                        @unknown default: state.status = "Unknown opening result"
                        }
                    }
                    transitioning = false
                }
            }
            .disabled(transitioning)
        }
        .padding(40)
    }
}

struct SpatialSceneView: View {
    let state: SpatialSceneState

    var body: some View {
        RealityView { content in
            content.add(state.root)
            state.begin()
        }
        .simultaneousGesture(SpatialTapGesture().targetedToAnyEntity().onEnded { _ in
            state.tap()
        })
        .simultaneousGesture(DragGesture().targetedToAnyEntity().onChanged { value in
            state.drag(translation: value.convert(value.translation3D, from: .global, to: state.parent))
        }.onEnded { _ in
            state.endDrag()
        })
        .onDisappear { state.finish() }
    }
}
