import SwiftUI

// MARK: - Meter Type Enum
enum MeterType: String, CaseIterable {
    case water = "water"
    case electricity = "electricity"
    case gas = "gas"

    var displayName: String {
        switch self {
        case .water: return "Wasser"
        case .electricity: return "Strom"
        case .gas: return "Gas"
        }
    }

    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .electricity: return "bolt.fill"
        case .gas: return "flame.fill"
        }
    }

    static let accentColors: [Color] = [.meterAccent1, .meterAccent2, .meterAccent3, .meterAccent4]
    static let darkAccentColors: [Color] = [.darkMeterAccent1, .darkMeterAccent2, .darkMeterAccent3, .darkMeterAccent4]
}

// MARK: - Color Extension for Meter Accent Colors
extension Color {
    static let meterAccent1 = Color(red: 0/255, green: 84/255, blue: 97/255) // #005461
    static let meterAccent2 = Color(red: 12/255, green: 119/255, blue: 121/255) // #0C7779
    static let meterAccent3 = Color(red: 36/255, green: 158/255, blue: 148/255) // #249E94
    static let meterAccent4 = Color(red: 59/255, green: 193/255, blue: 168/255) // #3BC1A8

    // Dark mode accent palette (higher contrast against dark backgrounds)
    static let darkMeterAccentPrimary = Color(red: 0/255, green: 180/255, blue: 190/255) // teal-cyan, bright for buttons
    static let darkMeterAccentSecondary = Color(red: 140/255, green: 220/255, blue: 210/255) // softer accent for text/details
    static let darkMeterAccent1 = Color(red: 20/255, green: 110/255, blue: 120/255)
    static let darkMeterAccent2 = Color(red: 16/255, green: 140/255, blue: 150/255)
    static let darkMeterAccent3 = Color(red: 0/255, green: 170/255, blue: 160/255)
    static let darkMeterAccent4 = Color(red: 0/255, green: 200/255, blue: 180/255)
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
