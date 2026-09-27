import Foundation
import AVFoundation

public final class AudioRouteObserver: @unchecked Sendable {
    public typealias RouteChangeHandler = @Sendable () -> Void

    private var observerToken: (any NSObjectProtocol)?
    private var handler: RouteChangeHandler?
    private let lock = NSLock()

    public init() {
        startObserving()
    }

    deinit {
        stopObserving()
    }

    public func setHandler(_ handler: @escaping RouteChangeHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
    }

    private func startObserving() {
        observerToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notifyRouteChange()
        }
    }

    private func stopObserving() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
    }

    private func notifyRouteChange() {
        lock.lock()
        let currentHandler = self.handler
        lock.unlock()
        currentHandler?()
    }
}
