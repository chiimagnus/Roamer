import Foundation
import SwiftUI

struct KeyEventsView: View {
    @State private var session = UUID().uuidString
    @State private var events: [[String: Any]] = []
    @State private var text = ""
    @FocusState private var focused: Bool

    private func record() {
        writeProbeState(["session": session, "events": events], name: "keys.json")
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("ROAMER KEY AUDIT").font(.title).bold()
            Text("EVENTS \(events.count)").font(.largeTitle.monospaced())
            Text("\(events.last?["characters"] as? String ?? "NONE") \(events.last?["phase"] as? String ?? "NONE")")
            TextField("KEYBOARD TARGET", text: $text)
                .textFieldStyle(.roundedBorder).focused($focused)
            Text("Keys are consumed here; use Interaction to test text editing.")
            RoundedRectangle(cornerRadius: 30).fill(.blue.opacity(0.5))
                .frame(width: 700, height: 300)
        }
        .padding(50)
        .onKeyPress(phases: [.down, .up]) { press in
            events.append([
                "characters": press.characters,
                "phase": press.phase.debugDescription,
                "modifiers": press.modifiers.rawValue,
            ])
            record()
            return .handled
        }
        .onAppear { record() }
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            focused = true
        }
    }
}
