import SwiftUI

enum SidebarDestination: Hashable {
    case settings
    case visualization
}

struct SidebarView: View {
    @Binding var showSidebar: Bool
    var onNavigate: (SidebarDestination) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let animationDuration: Double = 0.3

    private var accentColor: Color {
        colorScheme == .dark ? .darkMeterAccentPrimary : .meterAccent3
    }

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = geometry.size.width * 0.72

            ZStack(alignment: .leading) {
                // Dimming background
                Color.black
                    .opacity(showSidebar ? 0.4 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: animationDuration)) {
                            showSidebar = false
                        }
                    }

                // Drawer
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Menü")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    // Menu items
                    SidebarMenuItem(
                        title: "Einstellungen",
                        icon: "gear",
                        accentColor: accentColor,
                        colorScheme: colorScheme
                    ) { onNavigate(.settings) }

                    SidebarMenuItem(
                        title: "Visualisierung",
                        icon: "chart.bar.xaxis",
                        accentColor: accentColor,
                        colorScheme: colorScheme
                    ) { onNavigate(.visualization) }

                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 24)
                .frame(maxHeight: .infinity)
                .frame(width: drawerWidth)
                .background(
                    (colorScheme == .dark ? Color(.systemBackground) : .white)
                        .shadow(.drop(color: .black.opacity(0.15), radius: 12, x: 4))
                )
                .cornerRadius(16, corners: [.topRight, .bottomRight])
                .offset(x: showSidebar ? 0 : -drawerWidth)
                .animation(.easeInOut(duration: animationDuration), value: showSidebar)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Sidebar Menu Item

private struct SidebarMenuItem: View {
    let title: String
    let icon: String
    let accentColor: Color
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundColor(accentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
