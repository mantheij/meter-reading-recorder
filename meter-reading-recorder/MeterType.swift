import SwiftUI

// MARK: - Meter Type Enum
enum MeterType: String, CaseIterable {
    case water = "water"
    case electricity = "electricity"
    case gas = "gas"

    var displayName: String {
        switch self {
        case .water: return L10n.water
        case .electricity: return L10n.electricity
        case .gas: return L10n.gas
        }
    }

    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .electricity: return "bolt.fill"
        case .gas: return "flame.fill"
        }
    }

    var unit: String {
        switch self {
        case .water: return "m³"
        case .electricity: return "kWh"
        case .gas: return "m³"
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

    // Dark mode accent palette (high contrast against dark backgrounds)
    static let darkMeterAccentPrimary = Color(red: 0/255, green: 240/255, blue: 250/255) // electric teal-cyan for buttons
    static let darkMeterAccentSecondary = Color(red: 190/255, green: 252/255, blue: 245/255) // bright soft accent
    static let darkMeterAccent1 = Color(red: 110/255, green: 220/255, blue: 240/255)
    static let darkMeterAccent2 = Color(red: 70/255, green: 238/255, blue: 235/255)
    static let darkMeterAccent3 = Color(red: 45/255, green: 248/255, blue: 220/255)
    static let darkMeterAccent4 = Color(red: 20/255, green: 255/255, blue: 230/255)
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
