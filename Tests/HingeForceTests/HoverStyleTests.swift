import SwiftUI
import XCTest
@testable import HingeForce

@MainActor
final class HoverStyleTests: XCTestCase {
    /// The colour in the middle of `view` drawn at 1x, as 0...255 red, green and blue.
    private func centrePixel<V: View>(of view: V) throws -> (r: Int, g: Int, b: Int) {
        let renderer = ImageRenderer(content: view.frame(width: 80, height: 40))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let rep = NSBitmapImageRep(cgImage: image)
        // Read the stored values as they are: converting to another colour space would shift the greys.
        let c = try XCTUnwrap(rep.colorAt(x: image.width / 2, y: image.height / 2))
        return (Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }

    private func surface(hovering: Bool, rest: Color = Theme.pill, hover: Color = Theme.pillHover) -> some View {
        Color.clear.modifier(HoverSurface(shape: Rectangle(), rest: rest, hover: hover, startsHovering: hovering))
    }

    func testHoverColourIsE3E3E3() {
        XCTAssertEqual(Theme.pillHover, RGB(hex: 0xE3E3E3).color)
    }

    func testHoverIsDarkerThanTheRestingPill() {
        // 0.935 * 255 is about 238 (#EEEEEE); the hover grey is 227.
        XCTAssertLessThan(0xE3, Int((0.935 * 255).rounded()))
    }

    func testAButtonShowsItsRestingColourWithoutThePointer() throws {
        let p = try centrePixel(of: surface(hovering: false))
        XCTAssertEqual(p.r, Int((0.935 * 255).rounded()), accuracy: 1)
        XCTAssertEqual(p.r, p.g)
        XCTAssertEqual(p.g, p.b)
    }

    func testAButtonTurnsE3E3E3UnderThePointer() throws {
        let p = try centrePixel(of: surface(hovering: true))
        XCTAssertEqual(p.r, 0xE3, accuracy: 1)
        XCTAssertEqual(p.g, 0xE3, accuracy: 1)
        XCTAssertEqual(p.b, 0xE3, accuracy: 1)
    }

    func testAButtonWithNoBackgroundOfItsOwnGainsOneOnHover() throws {
        let resting = try centrePixel(of: ZStack { Color.white; surface(hovering: false, rest: .clear) })
        let hovered = try centrePixel(of: ZStack { Color.white; surface(hovering: true, rest: .clear) })
        XCTAssertEqual(resting.r, 255, accuracy: 1)
        XCTAssertEqual(hovered.r, 0xE3, accuracy: 1)
    }

    func testThePrimaryButtonDarkensSlightlyOnHover() throws {
        let rest = try centrePixel(of: surface(hovering: false, rest: Theme.yellow, hover: Theme.yellowHover))
        let hovered = try centrePixel(of: surface(hovering: true, rest: Theme.yellow, hover: Theme.yellowHover))
        XCTAssertLessThan(hovered.r, rest.r)
        XCTAssertLessThan(hovered.g, rest.g)
        XCTAssertLessThan(hovered.b, rest.b)
        XCTAssertGreaterThan(hovered.g, rest.g - 30, "the change should be subtle")
    }
}
