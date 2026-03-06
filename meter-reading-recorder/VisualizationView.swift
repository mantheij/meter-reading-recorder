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
                if viewModel.timeRange == .custom {
                    customRangeRow
                }
                if viewModel.hasEnoughData {
                    chartSection
                    if let summary = viewModel.summary {
                        summaryCard(summary)
                    }
                    if let trend = viewModel.trend {
                        trendSection(trend)
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
        .onChange(of: viewModel.selectedType)    { recompute() }
        .onChange(of: viewModel.timeRange)       { recompute() }
        .onChange(of: viewModel.customStartYear) { recompute() }
        .onChange(of: viewModel.customStartMonth){ recompute() }
        .onChange(of: viewModel.customEndYear)   { recompute() }
        .onChange(of: viewModel.customEndMonth)  { recompute() }
        .onChange(of: readings.count)            { recompute() }
        .onChange(of: appLanguage)               { recompute() }
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
        Picker(L10n.period, selection: $viewModel.timeRange) {
            ForEach(TimeRange.allCases, id: \.rawValue) { r in
                Text(r.displayName).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Custom Range Row

    private var customRangeRow: some View {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let years = Array((currentYear - 10)...currentYear)
        let monthSymbols = DateFormatter().monthSymbols ?? (1...12).map { "\($0)" }

        return VStack(spacing: AppTheme.Spacing.xs) {
            HStack {
                Text(L10n.from)
                    .frame(width: 40, alignment: .leading)
                Picker("", selection: $viewModel.customStartMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(monthSymbols[m - 1]).tag(m)
                    }
                }
                .pickerStyle(.menu)
                Picker("", selection: $viewModel.customStartYear) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            HStack {
                Text(L10n.to)
                    .frame(width: 40, alignment: .leading)
                Picker("", selection: $viewModel.customEndMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(monthSymbols[m - 1]).tag(m)
                    }
                }
                .pickerStyle(.menu)
                Picker("", selection: $viewModel.customEndYear) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    // MARK: - Accent Color

    private var accentColor: Color {
        AppTheme.meterAccent(for: MeterType.allCases.firstIndex(of: viewModel.selectedType) ?? 0)
    }

    // MARK: - Chart

    private var chartSection: some View {
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
        let groupLabel = L10n.month

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

    // MARK: - Trend Card

    private func trendSection(_ trend: ConsumptionTrend) -> some View {
        let unit = viewModel.selectedType.unit
        let dirColor = trendDirectionColor(trend.direction)
        let dirIcon  = trendDirectionIcon(trend.direction)
        let dirLabel = trendDirectionLabel(trend.direction)
        let slopeFormatted = String(format: "%+.2f", trend.slope)

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(L10n.consumptionTrend)
                .font(.headline)

            Chart {
                ForEach(Array(viewModel.dataPoints.enumerated()), id: \.offset) { i, point in
                    BarMark(
                        x: .value("Index", Double(i)),
                        y: .value(L10n.consumption, point.value)
                    )
                    .foregroundStyle(accentColor.opacity(0.25))
                }
                ForEach(trend.trendLine) { pt in
                    LineMark(
                        x: .value("Index", pt.index),
                        y: .value(L10n.consumption, pt.value)
                    )
                    .foregroundStyle(dirColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxisLabel(unit)
            .frame(height: 100)

            HStack {
                Image(systemName: dirIcon)
                    .foregroundColor(dirColor)
                Text(dirLabel)
                    .font(.subheadline)
                    .foregroundColor(dirColor)
                Spacer()
                Text("\(slopeFormatted) \(unit)/\(L10n.month)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

    private func trendDirectionColor(_ d: TrendDirection) -> Color {
        switch d {
        case .increasing: return .red
        case .decreasing: return .green
        case .stable:     return .secondary
        }
    }

    private func trendDirectionIcon(_ d: TrendDirection) -> String {
        switch d {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable:     return "arrow.right"
        }
    }

    private func trendDirectionLabel(_ d: TrendDirection) -> String {
        switch d {
        case .increasing: return L10n.trendIncreasing
        case .decreasing: return L10n.trendDecreasing
        case .stable:     return L10n.trendStable
        }
    }
}
