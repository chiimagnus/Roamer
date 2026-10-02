import Foundation

private struct StoredSimulatorState: Codable {
    let bootIdentifier: String
    let headPose: HeadPose
}

struct SimulatorStateStore: Sendable {
    private let rootURL: URL

    init(rootURL: URL? = nil) {
        self.rootURL = rootURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/Roamer/SimulatorState",
                isDirectory: true
            )
    }

    func loadHeadPose(udid: String, bootIdentifier: String) throws -> HeadPose {
        let url = stateURL(for: udid)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .identity
        }

        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(StoredSimulatorState.self, from: data)
        guard state.bootIdentifier == bootIdentifier else {
            return .identity
        }
        return state.headPose
    }

    func saveHeadPose(
        _ headPose: HeadPose,
        udid: String,
        bootIdentifier: String
    ) throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        let state = StoredSimulatorState(
            bootIdentifier: bootIdentifier,
            headPose: headPose
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL(for: udid), options: .atomic)
    }


    private func stateURL(for udid: String) -> URL {
        rootURL.appendingPathComponent("\(udid).json", isDirectory: false)
    }
}
