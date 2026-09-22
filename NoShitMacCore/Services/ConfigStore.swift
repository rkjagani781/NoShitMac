import Foundation

@MainActor
public final class ConfigStore: ObservableObject {
    @Published public private(set) var config: AppConfig

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("NoShitMac", isDirectory: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("config.json")
        self.config = Self.load(from: self.fileURL) ?? .default
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func reload() {
        config = Self.load(from: fileURL) ?? .default
    }

    public func save(_ newConfig: AppConfig) {
        config = newConfig
        persist()
    }

    public func update(_ block: (inout AppConfig) -> Void) {
        var copy = config
        block(&copy)
        save(copy)
    }

    private func persist() {
        do {
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("NoShitMac: failed to save config — \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }
}
