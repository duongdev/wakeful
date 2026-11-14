import Foundation
import Testing
@testable import WakefulCore

struct LogTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "wakeful-log-\(UUID().uuidString)")

    @Test func writesReadsAndClears() {
        let log = Log(directory: dir)
        log.info("first")
        log.error("second")
        let text = log.read()
        #expect(text.contains("INFO first"))
        #expect(text.contains("ERROR second"))
        log.clear()
        #expect(log.read().isEmpty)
    }

    @Test func rotatesAndKeepsOnlyTwoFiles() {
        let log = Log(directory: dir, maxBytes: 200)
        for i in 0..<50 { log.info("line \(i)") }
        let text = log.read()
        #expect(text.contains("line 49"))
        #expect(!text.contains("line 0 "), "oldest lines are dropped")
        #expect(text.utf8.count < 600)
    }
}
