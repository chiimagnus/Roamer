import Foundation

func writeProbeState(_ state: [String: Any], name: String) {
    let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(name)
    try! JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        .write(to: file, options: .atomic)
}
