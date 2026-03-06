import Foundation
import CoreData

// MARK: - Data Types

struct ConsumptionDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let date: Date
}

struct ConsumptionSummary {
    let periodLabel: String
    let total: Double
    let average: Double
    let trendPercent: Double?
}

enum TimeRange: Int, CaseIterable {
    case threeMonths, sixMonths, twelveMonths, all, custom

    var displayName: String {
        switch self {
        case .threeMonths:  return L10n.threeMonths
        case .sixMonths:    return L10n.sixMonths
        case .twelveMonths: return L10n.twelveMonths
        case .all:          return L10n.allTime
        case .custom:       return L10n.custom
        }
    }

    var months: Int? {
        switch self {
        case .threeMonths:  return 3
        case .sixMonths:    return 6
        case .twelveMonths: return 12
        case .all, .custom: return nil
        }
    }
}

// MARK: - ViewModel

@Observable
class VisualizationViewModel {
    var selectedType: MeterType = .water
    var timeRange: TimeRange = .twelveMonths

    // Custom range defaults: start = 6 months back, end = current month
    var customStartYear:  Int = {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        let month = c.month ?? 1
        let year  = c.year  ?? 2025
        // go back 5 months (so 6-month window including current month)
        if month > 5 { return year } else { return year - 1 }
    }()
    var customStartMonth: Int = {
        let month = Calendar.current.component(.month, from: Date())
        let start = month - 5
        return start > 0 ? start : start + 12
    }()
    var customEndYear:  Int = Calendar.current.component(.year,  from: Date())
    var customEndMonth: Int = Calendar.current.component(.month, from: Date())

    var dataPoints: [ConsumptionDataPoint] = []
    var summary: ConsumptionSummary?
    var hasEnoughData: Bool = false

    func compute(readings: [MeterReading]) {
        let calendar = Calendar.current
        let now = Date()

        // Filter by selected meter type
        let filtered = readings
            .filter { $0.meterType == selectedType.rawValue }
            .filter { $0.date != nil && $0.value != nil }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        // Apply time range filter
        let cutoffDate: Date? = {
            guard let months = timeRange.months else { return nil }
            return calendar.date(byAdding: .month, value: -months, to: now)
        }()

        let rangeFiltered: [MeterReading]
        if timeRange == .custom {
            let startDate = calendar.date(from: DateComponents(year: customStartYear, month: customStartMonth)) ?? .distantPast
            let endDateBase = calendar.date(from: DateComponents(year: customEndYear, month: customEndMonth))
            let endDate: Date = endDateBase.flatMap { calendar.date(byAdding: .month, value: 1, to: $0) } ?? .distantFuture
            rangeFiltered = filtered.filter {
                ($0.date ?? .distantPast) >= startDate && ($0.date ?? .distantPast) < endDate
            }
        } else if let cutoff = cutoffDate {
            rangeFiltered = filtered.filter { ($0.date ?? .distantPast) >= cutoff }
        } else {
            rangeFiltered = filtered
        }

        guard rangeFiltered.count >= 2 else {
            dataPoints = []
            summary = nil
            hasEnoughData = false
            return
        }

        hasEnoughData = true

        // Calculate consumption between consecutive readings
        var consumptions: [(date: Date, value: Double)] = []
        for i in 1..<rangeFiltered.count {
            let prev = Double(rangeFiltered[i - 1].value?.replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0
            let curr = Double(rangeFiltered[i].value?.replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0
            let diff = curr - prev
            if diff >= 0, let date = rangeFiltered[i].date {
                consumptions.append((date: date, value: diff))
            }
        }

        // Group by calendar period (always monthly)
        let grouped = Dictionary(grouping: consumptions) { item -> Date in
            periodBucket(for: item.date, calendar: calendar)
        }

        // Determine full period list
        let allPeriods: [Date]
        switch timeRange {
        case .custom:
            let startComponents = DateComponents(year: customStartYear, month: customStartMonth)
            let endComponents   = DateComponents(year: customEndYear,   month: customEndMonth)
            if let s = calendar.date(from: startComponents),
               let e = calendar.date(from: endComponents), s <= e {
                allPeriods = allPeriodBuckets(from: s, to: e, calendar: calendar)
            } else {
                allPeriods = []
            }
        case .all:
            allPeriods = grouped.keys.sorted()
        default:
            allPeriods = allPeriodBuckets(from: cutoffDate!, to: now, calendar: calendar)
        }

        // Build data points, filling 0 for periods without consumption data
        let dateFormatter = DateFormatter()
        let points = allPeriods.map { bucket -> ConsumptionDataPoint in
            let total = (grouped[bucket] ?? []).reduce(0) { $0 + $1.value }
            return ConsumptionDataPoint(
                label: formatPeriodLabel(for: bucket, formatter: dateFormatter),
                value: total,
                date: bucket
            )
        }

        dataPoints = points

        // Build summary
        let totalConsumption = points.reduce(0) { $0 + $1.value }
        let avgPerInterval = points.isEmpty ? 0 : totalConsumption / Double(points.count)

        // Period label
        let periodLabel: String = {
            guard let first = points.first, let last = points.last else { return "" }
            dateFormatter.dateFormat = "MMM yyyy"
            let start = dateFormatter.string(from: first.date)
            let end = dateFormatter.string(from: last.date)
            return start == end ? start : "\(start) – \(end)"
        }()

        // Trend: compare second half vs first half
        let trendPercent: Double? = {
            guard points.count >= 2 else { return nil }
            let mid = points.count / 2
            let firstHalf = points[0..<mid].reduce(0) { $0 + $1.value }
            let secondHalf = points[mid...].reduce(0) { $0 + $1.value }
            guard firstHalf > 0 else { return nil }
            return ((secondHalf - firstHalf) / firstHalf) * 100
        }()

        summary = ConsumptionSummary(
            periodLabel: periodLabel,
            total: totalConsumption,
            average: avgPerInterval,
            trendPercent: trendPercent
        )
    }

    // MARK: - Period Helpers

    private func periodBucket(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func allPeriodBuckets(from startDate: Date, to endDate: Date, calendar: Calendar) -> [Date] {
        var buckets: [Date] = []
        var current = periodBucket(for: startDate, calendar: calendar)
        let last = periodBucket(for: endDate, calendar: calendar)
        while current <= last {
            buckets.append(current)
            current = calendar.date(byAdding: .month, value: 1, to: current) ?? current
        }
        return buckets
    }

    private func formatPeriodLabel(for date: Date, formatter: DateFormatter) -> String {
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date)
    }
}
