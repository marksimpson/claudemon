import Testing
@testable import ClaudemonKit

@Suite("SessionStatus")
struct SessionStatusTests {
    @Test func permissionPromptMapsToPermission() {
        #expect(SessionStatus(lastEvent: "permission_prompt") == .permission)
    }

    @Test func idleMapsToIdle() {
        #expect(SessionStatus(lastEvent: "idle") == .idle)
    }

    @Test func sessionStartMapsToIdle() {
        #expect(SessionStatus(lastEvent: "session_start") == .idle)
    }

    @Test func userPromptMapsToWorking() {
        #expect(SessionStatus(lastEvent: "user_prompt") == .working)
    }

    @Test func unknownEventMapsToWorking() {
        #expect(SessionStatus(lastEvent: "something_else") == .working)
    }
}

@Suite("Tab index parsing")
struct TabIndexTests {
    @Test func parsesTabFromStandardFormat() {
        #expect(Session.parseTabIndex(from: "w0t3p0:6390C52A-B81C-4048-9302-3CCB94C34612") == 3)
    }

    @Test func parsesTabZero() {
        #expect(Session.parseTabIndex(from: "w1t0p0:SOME-GUID") == 0)
    }

    @Test func parsesMultiDigitTab() {
        #expect(Session.parseTabIndex(from: "w0t12p0:SOME-GUID") == 12)
    }

    @Test func returnsZeroForEmptyString() {
        #expect(Session.parseTabIndex(from: "") == 0)
    }

    @Test func returnsZeroForMalformedString() {
        #expect(Session.parseTabIndex(from: "garbage") == 0)
    }
}

@Suite("Window index parsing")
struct WindowIndexTests {
    @Test func parsesWindowFromStandardFormat() {
        #expect(Session.parseWindowIndex(from: "w2t3p0:6390C52A-B81C-4048-9302-3CCB94C34612") == 2)
    }

    @Test func parsesWindowZero() {
        #expect(Session.parseWindowIndex(from: "w0t5p0:SOME-GUID") == 0)
    }

    @Test func parsesMultiDigitWindow() {
        #expect(Session.parseWindowIndex(from: "w11t0p0:SOME-GUID") == 11)
    }

    @Test func returnsZeroForEmptyString() {
        #expect(Session.parseWindowIndex(from: "") == 0)
    }

    @Test func returnsZeroForMalformedString() {
        #expect(Session.parseWindowIndex(from: "garbage") == 0)
    }
}
