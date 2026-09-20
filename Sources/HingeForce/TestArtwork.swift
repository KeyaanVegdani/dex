import AppKit

/// Artwork for the Test System pages. The SVGs are embedded so the app has no resource-bundle dependency.
/// Laptop-Base.svg is embedded without its left-hand speaker dots, which are drawn in code (see `MicSpeaker`)
/// so they can change colour with the microphone.
enum TestArtwork {
    // MARK: Hinge page
    static let hingeBaseSize = CGSize(width: 474, height: 41)
    static let hingeLidSize = CGSize(width: 263, height: 407)
    /// The circle that juts out from the top-left of the base: the point the lid turns about.
    static let hingeCircleCenter = CGPoint(x: 10, y: 10)
    /// The lid's bottom end in its own image, which sits on that circle.
    static let hingeLidPivot = CGPoint(x: 246.5, y: 397.5)

    static let hingeBase: NSImage = Illustration.rasterize(svg: hingeBaseSVG, pixelScale: 3)
    static let hingeLid: NSImage = Illustration.rasterize(svg: hingeLidSVG, pixelScale: 3)

    // MARK: Mic page
    static let laptopSize = CGSize(width: 687, height: 370)
    static let laptopTop: NSImage = Illustration.rasterize(svg: laptopBaseSVG, pixelScale: 3)

    // MARK: Rotate page
    static let rotateSize = CGSize(width: 650, height: 319)
    static let rotateLaptop: NSImage = Illustration.rasterize(svg: rotateBaseSVG, pixelScale: 3)

    // MARK: Icons (36x36)
    static let hingeIcon: NSImage = Illustration.rasterize(svg: hingeIconSVG, pixelScale: 8)
    static let micIcon: NSImage = Illustration.rasterize(svg: micIconSVG, pixelScale: 8)
    static let trackpadIcon: NSImage = Illustration.rasterize(svg: trackpadIconSVG, pixelScale: 8)
    static let rotateIcon: NSImage = Illustration.rasterize(svg: rotateIconSVG, pixelScale: 8)
    static let iconSize = CGSize(width: 36, height: 36)

    /// Laptop-Bottom-Hinge.svg
    private static let hingeBaseSVG = #"""
<svg width="474" height="41" viewBox="0 0 474 41" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M9.67578 10.8438H473.676V26.8438C473.676 34.5757 467.408 40.8438 459.676 40.8438H23.6758C15.9438 40.8438 9.67578 34.5757 9.67578 26.8437V10.8438Z" fill="#E7EDEF"/>
<rect x="17.6758" y="16.8438" width="100" height="18" rx="8" fill="#D6E4E9"/>
<rect x="127.676" y="19.8438" width="33" height="12" rx="3" fill="#D6E4E9"/>
<rect x="170.676" y="19.8438" width="33" height="12" rx="3" fill="#D6E4E9"/>
<rect x="213.676" y="19.8438" width="12" height="12" rx="6" fill="#D6E4E9"/>
<circle cx="32.6758" cy="25.8438" r="5" fill="#E7EDEF"/>
<circle cx="46.6758" cy="25.8438" r="5" fill="#E7EDEF"/>
<circle cx="60.6758" cy="25.8438" r="5" fill="#E7EDEF"/>
<circle cx="74.6758" cy="25.8438" r="5" fill="#E7EDEF"/>
<circle cx="88.6758" cy="25.8438" r="5" fill="#E7EDEF"/>
<circle cx="102.676" cy="25.8438" r="5" fill="#E7EDEF"/>
<circle cx="10" cy="10" r="10" fill="#D6E4E9"/>
</svg>
"""#

    /// Laptop-Top-Hinge.svg
    private static let hingeLidSVG = #"""
<svg width="263" height="407" viewBox="0 0 263 407" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M262.43 395.844L20.3467 0.000592232L6.6969 8.34828C0.100659 12.3823 -1.97643 20.9998 2.05758 27.5961L229.532 399.552C233.566 406.148 242.184 408.225 248.78 404.191L262.43 395.844Z" fill="#E7EDEF"/>
</svg>
"""#

    /// Laptop-Base.svg without its left speaker dots.
    private static let laptopBaseSVG = #"""
<svg width="687" height="370" viewBox="0 0 687 370" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="687" height="370" rx="23" fill="#E7EDEF"/>
<rect x="91" y="33" width="505" height="205" rx="24" fill="#D6E4E9"/>
<line x1="173" y1="7" x2="173" y2="286" stroke="#E7EDEF" stroke-width="10"/>
<line x1="243" y1="7" x2="243" y2="286" stroke="#E7EDEF" stroke-width="10"/>
<line x1="313" y1="7" x2="313" y2="286" stroke="#E7EDEF" stroke-width="10"/>
<line x1="383" y1="7" x2="383" y2="286" stroke="#E7EDEF" stroke-width="10"/>
<line x1="453" y1="7" x2="453" y2="286" stroke="#E7EDEF" stroke-width="10"/>
<line x1="523" y1="7" x2="523" y2="286" stroke="#E7EDEF" stroke-width="10"/>
<line x1="645" y1="75" x2="59" y2="74.9999" stroke="#E7EDEF" stroke-width="10"/>
<line x1="645" y1="132" x2="59" y2="132" stroke="#E7EDEF" stroke-width="10"/>
<line x1="645" y1="189" x2="59" y2="189" stroke="#E7EDEF" stroke-width="10"/>
<rect x="211" y="259" width="265" height="91" rx="24" fill="#D6E4E9"/>
<circle cx="618" cy="42" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="42" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="42" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="42" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="59" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="59" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="59" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="59" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="76" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="76" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="76" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="76" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="93" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="93" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="93" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="93" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="110" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="110" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="110" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="110" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="127" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="127" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="127" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="127" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="144" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="144" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="144" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="144" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="161" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="161" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="161" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="161" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="178" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="178" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="178" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="178" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="195" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="195" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="195" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="195" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="212" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="212" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="212" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="212" r="6" fill="#D6E4E9"/>
<circle cx="618" cy="229" r="6" fill="#D6E4E9"/>
<circle cx="633.602" cy="229" r="6" fill="#D6E4E9"/>
<circle cx="649.199" cy="229" r="6" fill="#D6E4E9"/>
<circle cx="664.801" cy="229" r="6" fill="#D6E4E9"/>
</svg>
"""#

    /// Laptop-Rotate-Base.svg
    private static let rotateBaseSVG = #"""
<svg width="650" height="319" viewBox="0 0 650 319" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M88.6535 15.09C88.6535 6.75601 95.4095 0 103.743 0H533.807C542.141 0 548.897 6.75601 548.897 15.09V241.439H88.6535V15.09Z" fill="#E7EDEF"/>
<path d="M548.897 241.439H88.6535L0 295.763H650L548.897 241.439Z" fill="#E7EDEF"/>
<path d="M650 295.763H0C0 308.056 9.96511 318.021 22.2577 318.021H627.742C640.035 318.021 650 308.056 650 295.763Z" fill="#D6E4E9"/>
<path d="M104.121 28.67C104.121 20.3361 110.877 13.5801 119.211 13.5801H517.586C525.92 13.5801 532.676 20.3361 532.676 28.67V234.648H104.121V28.67Z" fill="#D6E4E9"/>
<path d="M253.69 268.99C254.064 268.737 254.505 268.602 254.957 268.602H403.057C403.449 268.602 403.834 268.703 404.175 268.897L429.405 283.233C431.426 284.381 430.611 287.464 428.287 287.464H233.741C231.508 287.464 230.624 284.575 232.473 283.325L253.69 268.99Z" fill="#D6E4E9"/>
</svg>
"""#

    /// Laptop-Logo-SVG.svg
    private static let hingeIconSVG = #"""
<svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="35.5" height="35.5" rx="17.75" fill="#EFEFEF"/>
<path d="M20.6495 8.52031L9.44084 23.524L24.9905 23.5583" stroke="#464646" stroke-width="2.1734" stroke-linejoin="bevel"/>
<path d="M19.7066 21V21.5434H20.7934V21H20.25H19.7066ZM17.25 16L16.962 16.4608C18.3388 17.3212 19.0224 18.4626 19.3653 19.3913C19.5373 19.8572 19.623 20.2686 19.6654 20.5606C19.6866 20.7064 19.6969 20.8215 19.702 20.8977C19.7045 20.9358 19.7056 20.9641 19.7062 20.9815C19.7065 20.9902 19.7066 20.9962 19.7066 20.9993C19.7066 21.0009 19.7067 21.0017 19.7067 21.0018C19.7067 21.0019 19.7067 21.0018 19.7067 21.0015C19.7067 21.0013 19.7067 21.0011 19.7066 21.0009C19.7066 21.0008 19.7066 21.0005 19.7066 21.0005C19.7066 21.0002 19.7066 21 20.25 21C20.7934 21 20.7934 20.9997 20.7934 20.9995C20.7934 20.9993 20.7934 20.9991 20.7933 20.9988C20.7933 20.9984 20.7933 20.9979 20.7933 20.9974C20.7933 20.9963 20.7933 20.9951 20.7933 20.9936C20.7933 20.9907 20.7933 20.9871 20.7932 20.9826C20.7931 20.9738 20.7928 20.962 20.7924 20.9474C20.7914 20.9181 20.7897 20.8774 20.7863 20.8264C20.7796 20.7244 20.7665 20.5807 20.7408 20.4042C20.6895 20.0517 20.5877 19.5646 20.3847 19.0149C19.9776 17.9124 19.1612 16.5538 17.538 15.5392L17.25 16Z" fill="#464646"/>
</svg>
"""#

    /// Laptop-Speaker-logo.svg
    private static let micIconSVG = #"""
<svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="35.5" height="35.5" rx="17.75" fill="#EFEFEF"/>
<path d="M20.9067 20.1973C19.2616 20.1973 18.1539 18.9655 18.1539 17.2047V11.6742C18.1539 9.90516 19.2616 8.68168 20.9067 8.68168C22.5601 8.68168 23.6678 9.90516 23.6678 11.6742V17.2047C23.6678 18.9655 22.5601 20.1973 20.9067 20.1973ZM10.7468 12.9556C9.97803 12.9556 9.35803 12.3356 9.35803 11.575C9.35803 10.8062 9.97803 10.1862 10.7468 10.1862C11.5074 10.1862 12.1274 10.8062 12.1274 11.575C12.1274 12.3356 11.5074 12.9556 10.7468 12.9556ZM10.7468 17.2543C9.97803 17.2543 9.35803 16.6343 9.35803 15.8738C9.35803 15.105 9.97803 14.485 10.7468 14.485C11.5074 14.485 12.1274 15.105 12.1274 15.8738C12.1274 16.6343 11.5074 17.2543 10.7468 17.2543ZM17.2197 26.2899C16.8725 26.2899 16.5914 26.0171 16.5914 25.6699C16.5914 25.3227 16.8725 25.0416 17.2197 25.0416H20.2867V23.1072C17.1123 22.8509 14.996 20.5693 14.996 17.337V15.6588C14.996 15.3116 15.2688 15.0388 15.616 15.0388C15.9632 15.0388 16.2442 15.3116 16.2442 15.6588V17.2874C16.2442 20.1064 18.0795 21.9746 20.9067 21.9746C23.7422 21.9746 25.5774 20.1064 25.5774 17.2874V15.6588C25.5774 15.3116 25.8502 15.0388 26.1974 15.0388C26.5529 15.0388 26.8257 15.3116 26.8257 15.6588V17.337C26.8257 20.5693 24.7094 22.8509 21.535 23.1072V25.0416H24.6019C24.9491 25.0416 25.2302 25.3227 25.2302 25.6699C25.2302 26.0171 24.9491 26.2899 24.6019 26.2899H17.2197ZM10.7468 21.5696C9.97803 21.5696 9.35803 20.9496 9.35803 20.189C9.35803 19.4202 9.97803 18.8002 10.7468 18.8002C11.5074 18.8002 12.1274 19.4202 12.1274 20.189C12.1274 20.9496 11.5074 21.5696 10.7468 21.5696ZM10.7468 25.8683C9.97803 25.8683 9.35803 25.2483 9.35803 24.4877C9.35803 23.7189 9.97803 23.0989 10.7468 23.0989C11.5074 23.0989 12.1274 23.7189 12.1274 24.4877C12.1274 25.2483 11.5074 25.8683 10.7468 25.8683Z" fill="#6C6C6C"/>
</svg>
"""#

    /// trackLogo.svg
    private static let trackpadIconSVG = #"""
<svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="35.5" height="35.5" rx="17.75" fill="#EFEFEF"/>
<path d="M14.6815 7C14.3628 7 14.0888 7.11463 13.8595 7.3439C13.6247 7.57316 13.5072 7.85554 13.5072 8.19105V20.1435C13.5072 20.1435 13.085 19.8779 12.2407 19.3467C11.3907 18.8211 10.6834 18.4352 10.1186 18.1892C9.96202 18.1165 9.79986 18.0606 9.63211 18.0214C9.46435 17.9823 9.2966 17.9627 9.12884 17.9627C8.25652 17.9627 7.7253 18.2255 7.53518 18.7512C7.34506 19.2824 7.25 19.548 7.25 19.548L10.3954 21.8882L12.8949 24.891C13.3367 25.4222 13.8735 25.8388 14.5054 26.1407C15.1428 26.4371 15.8055 26.5853 16.4932 26.5853H22.1382C22.9937 26.5853 23.7262 26.2805 24.3357 25.671C24.9452 25.0559 25.25 24.3122 25.25 23.4399V17.0652C25.25 16.6514 25.113 16.2964 24.839 16C24.565 15.7036 24.2211 15.5387 23.8073 15.5051L15.8474 14.8425V8.19105C15.8474 7.85554 15.7328 7.57316 15.5035 7.3439C15.2742 7.11463 15.0002 7 14.6815 7Z" fill="#464646"/>
</svg>
"""#

    /// Rotate-Logo.svg
    private static let rotateIconSVG = #"""
<svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="35.5" height="35.5" rx="17.75" fill="#EFEFEF"/>
<path d="M24.7821 9.65736V8.67162H25.0318C26.6256 8.67162 27.701 9.78538 27.701 11.4304V12.4802C27.701 12.7938 27.9634 13.0563 28.2771 13.0563C28.5843 13.0563 28.8467 12.7938 28.8467 12.4802V11.4304C28.8467 9.14528 27.2977 7.60906 25.0318 7.60906H24.7821V6.59131C24.7821 5.98963 24.3021 5.836 23.8412 6.18165L21.7737 7.71148C21.4409 7.95471 21.4345 8.27476 21.7737 8.5244L23.8412 10.0478C24.3021 10.3871 24.7821 10.2398 24.7821 9.65736ZM12.8124 23.0865H23.2779C24.4429 23.0865 25.243 22.2544 25.243 21.0574V13.9396C25.243 12.7426 24.4429 11.9233 23.2779 11.9233H12.8124C11.6474 11.9233 10.8537 12.7426 10.8537 13.9396V21.0574C10.8537 22.2544 11.6474 23.0865 12.8124 23.0865ZM13.0172 21.5311C12.6588 21.5311 12.422 21.275 12.422 20.8846V14.1188C12.422 13.7348 12.6588 13.4851 13.0172 13.4851H23.0795C23.438 13.4851 23.6748 13.7348 23.6748 14.1188V20.8846C23.6748 21.275 23.438 21.5311 23.0795 21.5311H13.0172ZM11.3082 25.346V26.3254H11.065C9.46472 26.3254 8.39577 25.2116 8.39577 23.5666V22.5168C8.39577 22.2032 8.13333 21.9407 7.81968 21.9407C7.51244 21.9407 7.25 22.2032 7.25 22.5168V23.5666C7.25 25.8517 8.79903 27.3815 11.065 27.3815H11.3082V28.3993C11.3082 29.0138 11.7883 29.161 12.2427 28.8217L14.3102 27.2855C14.6495 27.0423 14.6623 26.7286 14.3102 26.4726L12.2427 24.9492C11.7883 24.6035 11.3082 24.7572 11.3082 25.346Z" fill="#464646"/>
</svg>
"""#
}
