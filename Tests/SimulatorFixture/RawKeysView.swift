import Foundation
import SwiftUI
import UIKit

struct RawKeysView: UIViewRepresentable {
    func makeUIView(context: Context) -> RawKeyCaptureView { RawKeyCaptureView() }
    func updateUIView(_ uiView: RawKeyCaptureView, context: Context) {}
}

final class RawKeyCaptureView: UIView {
    private let session = UUID().uuidString
    private let label = UILabel()
    private var events: [[String: Any]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        layer.cornerRadius = 30
        label.font = .monospacedSystemFont(ofSize: 24, weight: .semibold)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -40),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
            record()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        capture(presses, phase: "down")
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        capture(presses, phase: "up")
    }

    private func capture(_ presses: Set<UIPress>, phase: String) {
        for press in presses {
            guard let key = press.key else { continue }
            events.append([
                "phase": phase, "usage": key.keyCode.rawValue,
                "characters": key.characters, "modifiers": key.modifierFlags.rawValue,
            ])
        }
        record()
    }

    private func record() {
        label.text = "ROAMER RAW KEY AUDIT\nfirstResponder=\(isFirstResponder) events=\(events.count)\n\n"
            + events.suffix(8).map { String(describing: $0) }.joined(separator: "\n")
        writeProbeState([
            "session": session, "focused": isFirstResponder, "events": events,
        ], name: "raw-keys.json")
    }
}
