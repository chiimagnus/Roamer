import Foundation
import SwiftUI

struct InteractionView: View {
    @State private var session = UUID().uuidString
    @State private var clicks = 0
    @State private var longs = 0
    @State private var doubles = 0
    @State private var singles = 0
    @State private var dragEvents = 0
    @State private var dragEnds = 0
    @State private var translation = CGSize.zero
    @State private var scale = 1.0
    @State private var magEvents = 0
    @State private var magEnds = 0
    @State private var rotation = 0.0
    @State private var rotEvents = 0
    @State private var rotEnds = 0
    @State private var text = ""
    @State private var submits = 0

    private func record() {
        writeProbeState([
            "session": session,
            "clicks": clicks, "longs": longs, "doubles": doubles, "singles": singles,
            "dragEvents": dragEvents, "dragEnds": dragEnds,
            "dx": translation.width, "dy": translation.height,
            "scale": scale, "magEvents": magEvents, "magEnds": magEnds,
            "rotation": rotation, "rotEvents": rotEvents, "rotEnds": rotEnds,
            "text": text, "submits": submits,
        ], name: "interaction.json")
    }

    var body: some View {
        VStack(spacing: 28) {
            Text("ROAMER INTERACTION AUDIT").font(.title).bold()
            HStack(spacing: 48) {
                Button("CLICK \(clicks)") { clicks += 1; record() }
                    .frame(width: 210, height: 70)
                Text("LONG \(longs)").frame(width: 210, height: 70)
                    .background(.orange.opacity(0.5)).contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.5) { longs += 1; record() }
                Text("DOUBLE \(doubles) SINGLE \(singles)").frame(width: 280, height: 70)
                    .background(.green.opacity(0.4)).contentShape(Rectangle())
                    .onTapGesture(count: 2) { doubles += 1; record() }
                    .onTapGesture { singles += 1; record() }
            }
            Text("DRAG \(dragEvents)/\(dragEnds)   SCALE \(scale, specifier: "%.3f")/\(magEnds)   ROT \(rotation, specifier: "%.1f")/\(rotEnds)")
                .font(.title2.monospaced())
            RoundedRectangle(cornerRadius: 30).fill(.blue.opacity(0.5))
                .frame(width: 900, height: 330)
                .overlay { Text("DRAG / MAGNIFY / ROTATE TARGET").font(.title).bold() }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture().onChanged { value in
                    dragEvents += 1; translation = value.translation; record()
                }.onEnded { value in
                    dragEnds += 1; translation = value.translation; record()
                })
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    scale = value.magnification; magEvents += 1; record()
                }.onEnded { value in
                    scale = value.magnification; magEnds += 1; record()
                })
                .simultaneousGesture(RotationGesture().onChanged { value in
                    rotation = value.degrees; rotEvents += 1; record()
                }.onEnded { value in
                    rotation = value.degrees; rotEnds += 1; record()
                })
            TextField("TEXT FIELD", text: $text).textFieldStyle(.roundedBorder)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .onChange(of: text) { record() }
                .onSubmit { submits += 1; record() }
            Text("TEXT [\(text)] SUBMIT \(submits)").font(.title2.monospaced())
        }
        .padding(30)
        .onAppear { record() }
    }
}
