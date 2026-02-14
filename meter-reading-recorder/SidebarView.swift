import SwiftUI

enum SidebarDestination: Hashable {
    case settings
    case visualization
}

struct SidebarView: View {
    @Binding var showSidebar: Bool
    var onNavigate: (SidebarDestination) -> Void

    private let animationDuration: Double = 0.3

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = geometry.size.width * 0.72

            ZStack(alignment: .leading) {
                Color.black
                    .opacity(showSidebar ? 0.4 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: animationDuration)) {
                            showSidebar = false
                        }
                    }

                VStack(alignment: .leading, spacing: 0) {
                    SidebarMenuItem(
                        title: L10n.settings,
                        icon: "gear",
                        accentColor: AppTheme.accentPrimary
                    ) { onNavigate(.settings) }

                    Divider()
                        .padding(.horizontal, AppTheme.Spacing.lg)

                    SidebarMenuItem(
                        title: L10n.visualization,
                        icon: "chart.bar.xaxis",
                        accentColor: AppTheme.accentPrimary
                    ) { onNavigate(.visualization) }

                    Divider()

                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + AppTheme.Spacing.lg)
                .frame(maxHeight: .infinity)
                .frame(width: drawerWidth)
                .background(
                    AppTheme.surfaceBackground
                        .shadow(.drop(color: .black.opacity(0.15), radius: 12, x: 4))
                )
                .cornerRadius(AppTheme.Radius.lg, corners: [.topRight, .bottomRight])
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(accentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
