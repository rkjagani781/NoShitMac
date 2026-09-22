import Foundation

@MainActor
public final class FeatureRegistry: ObservableObject {
    @Published public private(set) var features: [FeatureModule] = []

    private let services: FeatureServices
    private var started = false

    public init(services: FeatureServices) {
        self.services = services
    }

    public func register(_ feature: FeatureModule) {
        features.append(feature)
    }

    public func feature(id: String) -> FeatureModule? {
        features.first { $0.id == id }
    }

    public func startAll() {
        guard !started else { return }
        started = true
        for feature in features where feature.isEnabled {
            feature.start(services: services)
        }
    }

    public func stopAll() {
        for feature in features {
            feature.stop()
        }
        started = false
    }

    public func restartFeature(id: String) {
        guard let feature = feature(id: id) else { return }
        feature.stop()
        if feature.isEnabled {
            feature.start(services: services)
        }
    }

    public func restartAll() {
        stopAll()
        startAll()
    }
}
