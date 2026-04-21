import Testing
@testable import ClaudemonKit

@Suite("Dot positions")
struct DotStripTests {
    @Test func singleSessionStartsAtZero() {
        let positions = DotStrip.dotPositions(
            windowIndices: [0],
            dotSize: 8, tabSpacing: 3, windowSpacing: 10
        )
        #expect(positions == [0])
    }

    @Test func sessionsInSameWindowUseTabSpacing() {
        let positions = DotStrip.dotPositions(
            windowIndices: [0, 0, 0],
            dotSize: 8, tabSpacing: 3, windowSpacing: 10
        )
        // 0, then +8+3=11, then +8+3=22
        #expect(positions == [0, 11, 22])
    }

    @Test func windowBoundaryUsesWindowSpacing() {
        let positions = DotStrip.dotPositions(
            windowIndices: [0, 0, 1, 1],
            dotSize: 8, tabSpacing: 3, windowSpacing: 10
        )
        // 0, +8+3=11, +8+10=29 (window boundary), +8+3=40
        #expect(positions == [0, 11, 29, 40])
    }

    @Test func everyBoundaryIsAWindowWhenAllDiffer() {
        let positions = DotStrip.dotPositions(
            windowIndices: [0, 1, 2],
            dotSize: 8, tabSpacing: 3, windowSpacing: 10
        )
        // 0, +18, +18
        #expect(positions == [0, 18, 36])
    }

    @Test func emptyInputProducesEmptyOutput() {
        #expect(DotStrip.dotPositions(windowIndices: []) == [])
    }
}
