import AppKit

/// The lesson artwork, split into layers so the intro can animate the parts separately.
/// The SVG sources are embedded so the app has no resource-bundle dependency, and each layer
/// is re-rasterized at high resolution so it stays sharp when scaled up.
///
/// `plate` and `body` are full-canvas layers (`cakeSize`) that line up exactly when stacked.
enum Illustration {
    /// Cake canvas in SVG units. Candle positions below are in the same units.
    static let cakeSize = CGSize(width: 414, height: 266)
    /// Top-centre of each candle stick on the cake canvas (left, middle, right).
    static let candleTops: [CGPoint] = [CGPoint(x: 159, y: 0), CGPoint(x: 207, y: 26), CGPoint(x: 255, y: 0)]
    static let stickSize = CGSize(width: 18, height: 61)
    static let flameSize = CGSize(width: 39, height: 43)
    /// The smoke wisp (smoke.svg) is 21x40 with a 6-unit stroke; it hovers `smokeGap` units above a candle.
    static let smokeSize = CGSize(width: 21, height: 40)
    static let smokeStroke: CGFloat = 6
    static let smokeGap: CGFloat = 14
    /// Centre of the cake body on the canvas, used as the pivot for its tilt.
    static let bodyCenter = CGPoint(x: 207, y: 123)

    // MARK: Cutting lesson (Cakeee_2.svg and Knife + Indicator.svg share the same units)

    static let cutCakeSize = CGSize(width: 337, height: 368)
    /// Centre of the cake's top face, which the knife pivots around.
    static let cutCakeCenter = CGPoint(x: 168.5, y: 111.821)
    /// Half-width and half-height of the top face's ellipse.
    static let cutCakeRadii = CGSize(width: 145.5, height: 111.821)
    static let knifeSize = CGSize(width: 327, height: 166)
    /// Where the indicator line starts in the knife image; this sits on the cake's centre.
    static let knifePivot = CGPoint(x: 15.1422, y: 163.662)
    /// Direction the knife points in the image (pivot towards the blade), degrees clockwise from straight up.
    static let knifeRestAngle = atan2(161.329 - 15.1422, 163.662 - 78.4334) * 180 / .pi

    static let cutCake: NSImage = rasterize(svg: cutCakeSVG, pixelScale: 3)
    /// The two halves of Knife + Indicator.svg on the same canvas, so they line up when stacked
    /// but can move independently: the black indicator line, and the blade with its handle.
    static let knifeLine: NSImage = rasterize(svg: knifeSVG(knifeLineShapes), pixelScale: 4)
    static let knifeBlade: NSImage = rasterize(svg: knifeSVG(knifeBladeShapes), pixelScale: 4)

    // MARK: Pressing lesson (Platwe.svg, Cake Slice.svg, knife-2.svg, CakeFront.svg)
    //
    // All four share one scale. Positions are in those units with (0, 0) at the plate's top-left, so
    // negative y is above the plate. They come from the design screenshots.

    static let pressPlateSize = CGSize(width: 465, height: 121)
    /// The slice is drawn 0.4 units narrower on each side than its artwork, so while the cake front covers it
    /// its edges can never show through the front's anti-aliased edges as a faint line.
    static let pressSliceInset = 0.4
    static let pressSliceSize = CGSize(width: 194 - 2 * pressSliceInset, height: 227)
    static let pressKnifeSize = CGSize(width: 286, height: 90)
    static let pressFrontSize = CGSize(width: 387, height: 234)

    /// The whole cake sits centred on the plate; its top edge is 168 units above the plate's top.
    static let pressFrontOrigin = CGPoint(x: 232.136 - 193.258, y: -168)
    /// The slice is the right half of the cake: its left edge is at the cake's centre line.
    static let pressSliceOrigin = CGPoint(x: 232.136 - 0.258 + pressSliceInset, y: -168)
    /// The knife's x position, and its y when raised above the cake and when pushed all the way down.
    static let pressKnifeX = 234.0
    static let pressKnifeRaisedY = -267.0
    static let pressKnifeLoweredY = -19.0
    /// Where the cake front ends up: shrunk to 7% and parked on the left of the plate.
    static let pressFrontFinalScale = 0.07
    static let pressFrontFinalOrigin = CGPoint(x: 232.136 - 193.258, y: 21.5)

    static let pressPlate: NSImage = rasterize(svg: pressPlateSVG, pixelScale: 3)
    static let pressSlice: NSImage = rasterize(svg: pressSliceSVG, pixelScale: 4)
    static let pressKnife: NSImage = rasterize(svg: pressKnifeSVG, pixelScale: 4)
    static let pressFront: NSImage = rasterize(svg: pressFrontSVG, pixelScale: 3)

    // MARK: Washing lesson (Shower-Head.svg, rain-drop.svg, Mess-1...4.svg, Mess-3-1.svg; plate as in part 3)
    //
    // Same units as part 3, with (0, 0) at the plate's top-left. The positions come from the design screenshot.

    static let washHeadSize = CGSize(width: 71, height: 107)
    /// Where the shower head's pipe is fixed, in the head's own image; the head swings around this point.
    static let washHeadPivot = CGPoint(x: 35.5, y: 5)
    /// Top-left of the shower head when it hangs straight down, centred over the plate.
    static let washHeadOrigin = CGPoint(x: 232.136 - 35.5, y: -327.4)
    /// The rain drop (rain-drop.svg): a 4x16 capsule.
    static let washDropSize = CGSize(width: 4, height: 16)

    /// The five messes stuck to the plate, with the size of their artwork and where their top-left sits.
    struct Mess: Equatable {
        let name: String
        let size: CGSize
        let origin: CGPoint
        var xRange: ClosedRange<Double> { Double(origin.x)...Double(origin.x + size.width) }
    }
    static let washMesses: [Mess] = [
        Mess(name: "Mess-1", size: CGSize(width: 146, height: 43), origin: CGPoint(x: 34.0, y: 11.3)),
        Mess(name: "Mess-2", size: CGSize(width: 23, height: 10), origin: CGPoint(x: 192.8, y: 55.2)),
        Mess(name: "Mess-3-1", size: CGSize(width: 30, height: 9), origin: CGPoint(x: 251.0, y: 12.5)),
        Mess(name: "Mess-4", size: CGSize(width: 72, height: 16), origin: CGPoint(x: 245.7, y: 35.5)),
        Mess(name: "Mess-3", size: CGSize(width: 89, height: 18), origin: CGPoint(x: 332.7, y: 26.5)),
    ]

    static let washHead: NSImage = rasterize(svg: washHeadSVG, pixelScale: 4)
    static let washMessImages: [NSImage] = [washMess1SVG, washMess2SVG, washMess31SVG, washMess4SVG, washMess3SVG]
        .map { rasterize(svg: $0, pixelScale: 5) }

    static let plate: NSImage = rasterize(svg: canvasSVG(plateShapes), pixelScale: 3)
    static let body: NSImage = rasterize(svg: canvasSVG(bodyShapes), pixelScale: 3)
    /// One stick image; all three candles are the same shape.
    static let stick: NSImage = rasterize(svg: stickSVG, pixelScale: 10)
    static let flame: NSImage = rasterize(svg: flameSVG, pixelScale: 10)

    /// Draws the SVG into a bitmap `pixelScale` times larger than its natural size, and returns
    /// an image whose point size is still the natural size.
    private static func rasterize(svg: String, pixelScale: CGFloat) -> NSImage {
        guard let source = NSImage(data: Data(svg.utf8)) else { return NSImage() }
        let pixelsWide = Int(source.size.width * pixelScale)
        let pixelsHigh = Int(source.size.height * pixelScale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return source }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: source.size)
        image.addRepresentation(rep)
        return image
    }

    private static func canvasSVG(_ shapes: String) -> String {
        """
        <svg width="414" height="266" viewBox="0 0 414 266" fill="none" xmlns="http://www.w3.org/2000/svg">
        \(shapes)
        </svg>
        """
    }

    /// Cake-Base.svg: the plate (three shapes)...
    private static let plateShapes = #"""
    <path d="M414 186.411C414 220.88 321.323 248.823 207 248.823C92.6771 248.823 0 220.88 0 186.411C0 151.942 92.6771 124 207 124C321.323 124 414 151.942 414 186.411Z" fill="#E7EDEF"/>
    <path d="M414 186.411C414 220.88 321.323 248.823 207 248.823C92.6771 248.823 0 220.88 0 186.411V211.032C0 211.032 0 266 207 266C414 266 414 211.032 414 211.032V186.411Z" fill="#DBE6EA"/>
    <ellipse cx="207" cy="184" rx="182" ry="51" fill="#D6E4E9"/>
    """#

    /// ...and the three purple layers of the cake body.
    private static let bodyShapes = #"""
    <path d="M362 69.5C362 90.763 292.604 108 207 108C121.396 108 52 90.763 52 69.5C52 48.237 121.396 31 207 31C292.604 31 362 48.237 362 69.5Z" fill="#C9B0F0"/>
    <path d="M207 108C292.604 108 362 90.763 362 69.5V119.75C362 119.75 341.5 157 207 157C72.5 157 52 119.75 52 119.75V69.5C52 90.763 121.396 108 207 108Z" fill="#B596E5"/>
    <path d="M52 170C52 170 52 216 207 216C362 216 362 170 362 170V119.75C362 119.75 341.5 157 207 157C72.5 157 52 119.75 52 119.75V170Z" fill="#A086E1"/>
    """#

    /// The left candle from Cake-Base.svg, cropped to its own 18x61 box via the viewBox.
    private static let stickSVG = #"""
    <svg width="18" height="61" viewBox="150 0 18 61" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M150 9C150 4.02944 154.029 0 159 0V0C163.971 0 168 4.02944 168 9V59C168 60.1046 167.105 61 166 61H152C150.895 61 150 60.1046 150 59V9Z" fill="#54525F"/>
    </svg>
    """#

    private static let flameSVG = #"""
    <svg width="39" height="43" viewBox="0 0 39 43" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M13.8171 2.99999C16.1265 -1.00001 21.9 -0.999999 24.2094 3L37.2219 25.5383C38.8249 28.3149 37.9619 31.8611 35.2623 33.5905L22.2498 41.9266C20.2771 43.1903 17.7493 43.1903 15.7767 41.9266L2.76417 33.5905C0.0645545 31.8611 -0.798459 28.3148 0.804575 25.5383L13.8171 2.99999Z" fill="#FF5900"/>
    </svg>
    """#

    /// Cakeee_2.svg. Its solid line from the centre to the back rim marks where the cut starts;
    /// the dotted cut line the player has to reach is drawn separately, on top.
    private static let cutCakeSVG = #"""
    <svg width="337" height="368" viewBox="0 0 337 368" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M337 238.5C337 297.318 261.56 345 168.5 345C75.44 345 0 297.318 0 238.5C0 179.682 75.44 132 168.5 132C261.56 132 337 179.682 337 238.5Z" fill="#E7EDEF"/>
    <path d="M337 238.5C337 297.318 261.56 345 168.5 345C75.44 345 0 297.318 0 238.5V282C0 282 35.5 367.5 168.5 367.5C301.5 367.5 337 282 337 282V238.5Z" fill="#DBE6EA"/>
    <ellipse cx="168.5" cy="237" rx="152.5" ry="94" fill="#D6E4E9"/>
    <path d="M314 111.821C314 173.578 248.857 223.642 168.5 223.642C88.1424 223.642 23 173.578 23 111.821C23 50.0639 88.1424 0 168.5 0C248.857 0 314 50.0639 314 111.821Z" fill="#C9B0F0"/>
    <path d="M314 111.821C314 173.578 248.857 223.642 168.5 223.642C88.1424 223.642 23 173.578 23 111.821V192.192C23 192.192 51.2015 272.563 168.5 272.563C285.798 272.563 314 192.192 314 192.192V111.821Z" fill="#B596E5"/>
    <path d="M314 192.192C314 192.192 285.798 272.563 168.5 272.563C51.2015 272.563 23 192.192 23 192.192L24.0005 235.123C24.0005 235.123 43.9639 312 168.5 312C293.036 312 313 235.123 313 235.123L314 192.192Z" fill="#A086E1"/>
    <line x1="166" y1="106" x2="166" y2="2" stroke="#B596E5" stroke-width="4" stroke-linecap="round"/>
    </svg>
    """#

    private static func knifeSVG(_ shapes: String) -> String {
        """
        <svg width="327" height="166" viewBox="0 0 327 166" fill="none" xmlns="http://www.w3.org/2000/svg">
        \(shapes)
        </svg>
        """
    }

    /// Knife + Indicator.svg: the black indicator line, which starts at `knifePivot` ...
    private static let knifeLineShapes = #"""
    <path d="M15.1422 163.662L161.329 78.4334" stroke="black" stroke-width="4" stroke-linecap="round"/>
    """#

    /// ... and the knife itself (handle and blade).
    private static let knifeBladeShapes = #"""
    <path d="M270.799 18.8357L281.831 24.0909L307.131 9.78624C310.315 7.98622 310.124 3.33816 306.803 1.80539C305.533 1.21917 304.062 1.25864 302.826 1.91215L270.799 18.8357Z" fill="#916342"/>
    <path d="M209.575 40.9245L200.191 69.7271L225.972 55.3157L234.671 27.2525L209.575 40.9245Z" fill="#79929A"/>
    <path d="M187.586 52.9037L176.32 83.0711L200.191 69.7271L209.575 40.9245L187.586 52.9037ZM253.901 39.7033L225.972 55.3157L234.671 27.2525L259.768 13.5805L253.901 39.7033ZM261.779 35.2998L281.831 24.0909L270.799 18.8357L265.283 16.2081L261.779 35.2998Z" fill="#8DA7B0"/>
    <path d="M259.768 13.5805L253.901 39.7033L261.779 35.2998L265.283 16.2081L259.768 13.5805Z" fill="#79929A"/>
    """#

    /// Platwe.svg
    private static let pressPlateSVG = #"""
    <svg width="465" height="121" viewBox="0 0 465 121" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M464.273 44.1625C464.273 68.5528 360.342 88.325 232.136 88.325C103.931 88.325 0 68.5528 0 44.1625C0 19.7722 103.931 0 232.136 0C360.342 0 464.273 19.7722 464.273 44.1625Z" fill="#E7EDEF"/>
    <path d="M464.273 44.1625C464.273 68.5528 360.342 88.325 232.136 88.325C103.931 88.325 0 68.5528 0 44.1625V79.2661C0 79.2661 0 120.786 232.136 120.786C464.273 120.786 464.273 79.2661 464.273 79.2661V44.1625Z" fill="#DBE6EA"/>
    <ellipse cx="232.136" cy="40.0105" rx="210.244" ry="40.0105" fill="#D6E4E9"/>
    </svg>
    """#

    /// Cake Slice.svg
    private static let pressSliceSVG = #"""
    <svg width="194" height="227" viewBox="0 0 194 227" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M193.516 14.3434C193.516 6.21329 141.427 0 0.257812 0V14.3434H193.516Z" fill="#C9B0F0"/>
    <path d="M193.516 96L0.257812 110.5V136L193.516 118V96Z" fill="#B596E5"/>
    <path d="M0.257812 14.3434V110.5L193.516 96V14.3434H0.257812Z" fill="#E1D3EB"/>
    <path d="M0.257812 227L193.516 193.5V118L0.257812 136V227Z" fill="#E1D3EB"/>
    <line x1="0.211203" y1="45.5124" x2="193.211" y2="39.5124" stroke="#EEE2F7" stroke-width="3"/>
    <path d="M193.758 145.012L0.257815 167.012" stroke="#EEE2F7" stroke-width="3"/>
    <line x1="0.18794" y1="81.5133" x2="193.188" y2="72.5133" stroke="#EEE2F7" stroke-width="3"/>
    <path d="M191.758 172.012L0.257774 205.512" stroke="#EEE2F7" stroke-width="3"/>
    </svg>
    """#

    /// knife-2.svg
    private static let pressKnifeSVG = #"""
    <svg width="286" height="90" viewBox="0 0 286 90" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M212.726 33.0589L221.582 11.8813L274.917 0.203504C281.629 -1.26596 287.185 5.47917 284.458 11.7851C283.415 14.1968 281.307 15.9843 278.757 16.6191L212.726 33.0589Z" fill="#916342"/>
    <path d="M99.355 78.8524L50.1317 50.2956L104.274 38.1648L151.612 66.5445L99.355 78.8524Z" fill="#79929A"/>
    <path d="M53.5677 89.6365L0.000100371 61.5279L50.1317 50.2956L99.355 78.8524L53.5677 89.6365ZM162.928 25.023L104.274 38.1648L151.612 66.5445L203.87 54.2366L162.928 25.023ZM179.471 21.3164L221.582 11.8813L212.726 33.0589L208.298 43.6478L179.471 21.3164Z" fill="#8DA7B0"/>
    <path d="M203.87 54.2366L162.928 25.023L179.471 21.3164L208.298 43.6478L203.87 54.2366Z" fill="#79929A"/>
    </svg>
    """#

    /// CakeFront.svg, with its top face shapes overlapping their neighbours by up to a unit (same colour) so
    /// they don't leave a hairline where they meet.
    private static let pressFrontSVG = #"""
    <svg width="387" height="234" viewBox="0 0 387 234" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M386.516 109.651C299.324 141.924 92.8545 138.149 0 109.651V204.959C56.2412 238.931 309.138 246.102 386.516 204.959V109.651Z" fill="#A086E1"/>
    <path d="M386.516 14.3434C386.516 22.4735 299.992 29.0642 193.258 29.0642C86.5246 29.0642 0 22.4735 0 14.3434V109.651C92.8545 138.149 299.324 141.924 386.516 109.651V14.3434Z" fill="#B596E5"/>
    <path d="M0 14.3434C0 22.4735 86.5246 29.0642 193.258 29.0642H194.258V0H193.258C86.5246 0 0 6.21329 0 14.3434Z" fill="#C9B0F0"/>
    <path d="M192.758 29.0642C299.992 29.0642 386.516 22.4735 386.516 14.3434V13.8434H192.758V29.0642Z" fill="#C9B0F0"/>
    </svg>
    """#

    /// Shower-Head.svg
    private static let washHeadSVG = #"""
    <svg width="71" height="107" viewBox="0 0 71 107" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M35.5 62C15.8939 62 0 77.8939 0 97.5H71C71 77.8939 55.1061 62 35.5 62Z" fill="#E7EDEF"/>
    <path d="M71 97.5H0V107H71V97.5Z" fill="#D6E4E9"/>
    <line x1="36" y1="62" x2="36" y2="5" stroke="#D6E4E9" stroke-width="10" stroke-linecap="round"/>
    </svg>
    """#

    /// Mess-1.svg
    private static let washMess1SVG = #"""
    <svg width="146" height="43" viewBox="0 0 146 43" fill="none" xmlns="http://www.w3.org/2000/svg">
    <ellipse cx="73" cy="28" rx="73" ry="15" fill="#B596E5"/>
    <path d="M82.5 0L70 21L98.5 29.5L117.5 27L109.402 0H82.5Z" fill="#E1D3EB"/>
    </svg>
    """#

    /// Mess-2.svg
    private static let washMess2SVG = #"""
    <svg width="23" height="10" viewBox="0 0 23 10" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M0.894584 5.98629L9.36997 0.336038C10.0003 -0.0841721 10.8139 -0.112194 11.4716 0.263653L21.3596 5.9139C23.1403 6.93145 22.4182 9.65039 20.3673 9.65039H2.00399C0.0251727 9.65039 -0.75189 7.08394 0.894584 5.98629Z" fill="#B596E5"/>
    </svg>
    """#

    /// Mess-3-1.svg
    private static let washMess31SVG = #"""
    <svg width="30" height="9" viewBox="0 0 30 9" fill="none" xmlns="http://www.w3.org/2000/svg">
    <ellipse cx="15" cy="4.5" rx="15" ry="4.5" fill="#B596E5"/>
    </svg>
    """#

    /// Mess-4.svg
    private static let washMess4SVG = #"""
    <svg width="72" height="16" viewBox="0 0 72 16" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M0 11L32.9072 0L71.5 16L0 11Z" fill="#E1D3EB"/>
    </svg>
    """#

    /// Mess-3.svg (the big oval on the right of the plate in the design)
    private static let washMess3SVG = #"""
    <svg width="89" height="18" viewBox="0 0 89 18" fill="none" xmlns="http://www.w3.org/2000/svg">
    <ellipse cx="44.5" cy="9" rx="44.5" ry="9" fill="#B596E5"/>
    </svg>
    """#
}
