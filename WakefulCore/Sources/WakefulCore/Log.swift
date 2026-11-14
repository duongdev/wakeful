import Foundation
import os

/// Writes to `os.Logger` and to a small rotating file the user can view, copy and clear.
public final class Log: @unchecked Sendable {
    public static let shared = Log(directory: FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/Wakeful", directoryHint: .isDirectory))

    public let fileURL: URL
    private let previousURL: URL
    private let maxBytes: Int
    private let lock = NSLock()
    private let logger = Logger(subsystem: "dev.duongdev.Wakeful", category: "app")
    private let timestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: false, timeZone: .current)

    public init(directory: URL, maxBytes: Int = 512 * 1024) {
        fileURL = directory.appending(path: "wakeful.log")
        previousURL = directory.appending(path: "wakeful.1.log")
        self.maxBytes = maxBytes
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append("INFO", message)
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        append("ERROR", message)
    }

    /// Current and previous file, oldest first.
    public func read() -> String {
        lock.withLock {
            [previousURL, fileURL].compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        }
    }

    public func clear() {
        lock.withLock {
            try? FileManager.default.removeItem(at: previousURL)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func append(_ level: String, _ message: String) {
        let line = "\(Date().formatted(timestamp)) \(level) \(message)\n"
        lock.withLock {
            let fm = FileManager.default
            // Two files of maxBytes each: about 1 MB in total.
            if let size = try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? Int, size >= maxBytes {
                try? fm.removeItem(at: previousURL)
                try? fm.moveItem(at: fileURL, to: previousURL)
            }
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
