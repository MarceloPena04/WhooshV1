import CoreGraphics
import Foundation
import Testing
import WhooshCore

/// Window stacks measured on the M0 test machine (1512 x 982 pt display),
/// listed front to back as the window server reports them.
struct WindowSelectionTests {
    private func window(_ id: UInt32, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> WindowCandidate {
        WindowCandidate(windowID: id, frame: CGRect(x: x, y: y, width: width, height: height))
    }

    @Test func fullScreenSafariSkipsItsToolbarStrip() {
        let toolbar = window(2145, 0, 37, 1512, 119)
        let page = window(99, 0, 37, 1512, 945)
        #expect(WindowSelection.windowInUse([toolbar, page]) == page)
    }

    @Test func fullScreenChromeSkipsStripsThatOverlapItsWindow() {
        let toolbar = window(72, 0, 37, 1512, 166)
        let bar = window(54, 0, 78, 1512, 81)
        let page = window(51, 0, 159, 1512, 823)
        #expect(WindowSelection.windowInUse([toolbar, bar, page]) == page)
    }

    @Test func thinTitleStripIsIgnored() {
        let titleStrip = window(48844, 1512, 24, 1366, 44)
        let main = window(48842, 1512, 24, 1366, 1000)
        #expect(WindowSelection.windowInUse([titleStrip, main]) == main)
    }

    @Test func smallerDocumentInFrontStaysTheWindowInUse() {
        let front = window(1, 200, 200, 600, 400)
        let behind = window(2, 100, 100, 1200, 800)
        #expect(WindowSelection.windowInUse([front, behind]) == front)
    }

    @Test func sameWidthWindowsThatDoNotTouchStaySeparate() {
        let front = window(1, 100, 100, 800, 200)
        let behind = window(2, 100, 500, 800, 400)
        #expect(WindowSelection.windowInUse([front, behind]) == front)
    }

    @Test func noUsableWindow() {
        #expect(WindowSelection.windowInUse([]) == nil)
        #expect(WindowSelection.windowInUse([window(1, 0, 0, 54, 40)]) == nil)
    }
}
