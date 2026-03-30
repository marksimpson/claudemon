import Foundation
import SwiftUI

@MainActor
public class SessionStore: ObservableObject {
    @Published public var sessions: [Session] = []

    private var directorySource: DispatchSourceFileSystemObject?
    private var livenessTimer: Timer?
    private let stateDirectory: URL
    private let sessionsDirectory: URL
    private let loader: SessionLoader

    public init(
        stateDirectory: URL? = nil,
        sessionsDirectory: URL? = nil,
        loader: SessionLoader = SessionLoader()
    ) {
        self.stateDirectory = stateDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".claude/claudemon")
        self.sessionsDirectory = sessionsDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".claude/sessions")
        self.loader = loader
        reload()
        startWatching()
        startLivenessTimer()
    }

    deinit {
        directorySource?.cancel()
        livenessTimer?.invalidate()
    }

    public func reload() {
        sessions = loader.load(
            stateDirectory: stateDirectory,
            sessionsDirectory: sessionsDirectory
        )
    }

    private func startLivenessTimer() {
        livenessTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
    }

    private func startWatching() {
        let path = stateDirectory.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.reload()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        directorySource = source
    }
}
