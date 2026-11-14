import Foundation
import IOKit.pwr_mgt
import Testing
@testable import WakefulCore

/// Uses real IOKit assertions for a moment; each test releases what it creates.
@MainActor
struct PowerAssertionTests {
    private func heldByThisProcess(named name: String) -> Bool {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let all = byProcess?.takeRetainedValue() as? [Int: [[String: Any]]] else { return false }
        let mine = all[Int(getpid())] ?? []
        return mine.contains { $0[kIOPMAssertionNameKey] as? String == name }
    }

    @Test func ensureHeldRecreatesAReleasedAssertion() throws {
        let name = "Wakeful test \(UUID().uuidString)"
        let assertion = PowerAssertion(name: name)
        assertion.set(.system)
        #expect(heldByThisProcess(named: name))

        // Something outside the app's control drops the assertion.
        IOPMAssertionRelease(try #require(assertion.heldID))
        #expect(!heldByThisProcess(named: name))

        #expect(assertion.ensureHeld(), "reports that it had to re-create")
        #expect(heldByThisProcess(named: name))
        #expect(!assertion.ensureHeld(), "a held assertion is left alone")

        assertion.set(nil)
        #expect(!heldByThisProcess(named: name))
    }

    @Test func ensureHeldDoesNothingWhenNotWanted() {
        let name = "Wakeful test \(UUID().uuidString)"
        let assertion = PowerAssertion(name: name)
        #expect(!assertion.ensureHeld())
        #expect(!heldByThisProcess(named: name))
    }
}
