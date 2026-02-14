import SwiftUI
import CoreData

struct MeterTypeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let colorScheme: ColorScheme
    var body: some View {
        List {
            ForEach(Array(MeterType.allCases.enumerated()), id: \.element) { index, type in
                let accent = colorScheme == .dark ? MeterType.darkAccentColors[index % MeterType.darkAccentColors.count] : MeterType.accentColors[index % MeterType.accentColors.count]
                let opacity = colorScheme == .dark ? 0.35 : 0.15
                NavigationLink(destination: MeterTypeReadingsView(type: type)) {
                    Text(type.displayName)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .font(.headline)
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accent.opacity(opacity))
                        .cornerRadius(8)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationBarTitleDisplayMode(.large)
    }
}
