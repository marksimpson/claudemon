import Testing
@testable import ClaudemonKit

@Suite("ITerm")
struct ITermTests {
    @Test func parsesGUIDFromStandardFormat() {
        let guid = ITerm.parseGUID(from: "w0t3p0:6390C52A-B81C-4048-9302-3CCB94C34612")
        #expect(guid == "6390C52A-B81C-4048-9302-3CCB94C34612")
    }

    @Test func returnsNilForMissingColon() {
        #expect(ITerm.parseGUID(from: "w0t3p0") == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(ITerm.parseGUID(from: "") == nil)
    }

    @Test func preservesGUIDWithColons() {
        let guid = ITerm.parseGUID(from: "w0t0p0:ABC:DEF")
        #expect(guid == "ABC:DEF")
    }

    @Test func generatesValidAppleScript() {
        let script = ITerm.activationScript(for: "MY-GUID-123")
        #expect(script.contains("\"MY-GUID-123\""))
        #expect(script.contains("tell application \"iTerm2\""))
        #expect(script.contains("select t"))
    }
}
