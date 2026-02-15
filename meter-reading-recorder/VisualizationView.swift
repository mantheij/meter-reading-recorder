import SwiftUI
import Charts
import CoreData

struct VisualizationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appLanguage) private var appLanguage
    @EnvironmentObject private var authService: AuthService

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MeterReading.date, ascending: true)],
        predicate: NSPredicate(format: "softDeleted == NO"),
        animation: .default
    ) private var readings: FetchedResults<MeterReading>

    @State private var viewModel = VisualizationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                meterTypePicker
                controlsRow
                if viewModel.hasEnoughData {
                    chartSection
                    if let summary = viewModel.summary {
                        summaryCard(summary)
                    }
                } else {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: L10n.noDataForVisualization,
                        subtitle: L10n.noDataForVisualizationSubtitle
                    )
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle(L10n.visualization)
        .onChange(of: authService.currentUserId) {
            readings.nsPredicate = MeterReading.scopedPredicate(userId: authService.currentUserId)
        }
        .onAppear {
            readings.nsPredicate = MeterReading.scopedPredicate(userId: authService.currentUserId)
            recompute()
        }
        .onChange(of: viewModel.selectedType) { recompute() }
        .onChange(of: viewModel.grouping) { recompute() }
        .onChange(of: viewModel.timeRange) { recompute() }
        .onChange(of: readings.count) { recompute() }
        .onChange(of: appLanguage) { recompute() }
    }

    // MARK: - Meter Type Picker

    private var meterTypePicker: some View {
        Picker(L10n.selectMeterType, selection: $viewModel.selectedType) {
            ForEach(MeterType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Picker(L10n.consumption, selection: $viewModel.grouping) {
                ForEach(TimeGrouping.allCases, id: \.rawValue) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .pickerStyle(.segmented)

            Picker(L10n.period, selection: $viewModel.timeRange) {
                ForEach(TimeRange.allCases, id: \.rawValue) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        let accentColor = AppTheme.meterAccent(for: MeterType.allCases.firstIndex(of: viewModel.selectedType) ?? 0)

        return Chart(viewModel.dataPoints) { point in
            BarMark(
                x: .value(L10n.period, point.label),
                y: .value(L10n.consumption, point.value)
            )
            .foregroundStyle(accentColor)
            .cornerRadius(4)
        }
        .chartYAxisLabel(viewModel.selectedType.unit)
        .frame(height: 240)
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Summary Card

    private func summaryCard(_ summary: ConsumptionSummary) -> some View {
        let unit = viewModel.selectedType.unit
        let groupLabel = viewModel.grouping.displayName

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("\(L10n.period): \(summary.periodLabel)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text(L10n.total)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f %@", summary.total, unit))
                    .font(.headline)
            }

            HStack {
                Text("\(L10n.averagePer) \(groupLabel)")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f %@", summary.average, unit))
                    .font(.subheadline)
            }

            if let trend = summary.trendPercent {
                HStack {
                    Text(L10n.trend)
                        .font(.subheadline)
                    Spacer()
                    Text("\(trendArrow(trend)) \(String(format: "%.0f%%", abs(trend))) \(L10n.vsLastPeriod)")
                        .font(.subheadline)
                        .foregroundColor(trendColor(trend))
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func recompute() {
        viewModel.compute(readings: Array(readings))
    }

    private func trendArrow(_ percent: Double) -> String {
        if percent > 1 { return "↑" }
        if percent < -1 { return "↓" }
        return "→"
    }

    private func trendColor(_ percent: Double) -> Color {
        if percent > 1 { return .red }
        if percent < -1 { return .green }
        return .secondary
    }
}
