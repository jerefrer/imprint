import SwiftUI

enum Theme {
    // Palette extraite de l'icône (polaroid vintage sur papier crème)
    static let paper      = Color(red: 0.949, green: 0.910, blue: 0.836)   // #F2E8D5
    static let paperDeep  = Color(red: 0.886, green: 0.835, blue: 0.741)
    static let ink        = Color(red: 0.361, green: 0.227, blue: 0.129)   // #5C3A21
    static let inkSoft    = Color(red: 0.482, green: 0.349, blue: 0.231)
    static let mountain   = Color(red: 0.388, green: 0.471, blue: 0.490)
    static let success    = Color(red: 0.353, green: 0.557, blue: 0.353)
    static let muted      = Color(red: 0.624, green: 0.561, blue: 0.443)
    static let warning    = Color(red: 0.769, green: 0.490, blue: 0.220)

    static let titleFont   = Font.system(size: 32, weight: .regular, design: .serif)
    static let headingFont = Font.system(size: 18, weight: .medium, design: .serif)
    static let bodyFont    = Font.system(size: 13, weight: .regular)
    static let smallFont   = Font.system(size: 11, weight: .regular)
    static let monoFont    = Font.system(size: 12, weight: .regular, design: .monospaced)
}
