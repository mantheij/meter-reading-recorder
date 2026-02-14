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

enum TimeGrouping: Int, CaseIterable {
    case week, month

    var displayName: String {
        switch self {
        case .week: return L10n.week
        case .month: return L10n.month
        }
    }
}

enum TimeRange: Int, CaseIterable {
    case threeMonths, sixMonths, twelveMonths, all

    var displayName: String {
        switch self {
        case .threeMonths: return L10n.threeMonths
        case .sixMonths: return L10n.sixMonths
        case .twelveMonths: return L10n.twelveMonths
        case .all: return L10n.allTime
        }
    }

    var months: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .twelveMonths: return 12
        case .all: return nil
        }
    }
}

// MARK: - ViewModel

@Observable
class VisualizationViewModel {
    var selectedType: MeterType = .water
    var grouping: TimeGrouping = .month
    var timeRange: TimeRange = .twelveMonths

    var dataPoints: [ConsumptionDataPoint] = []
    var summary: ConsumptionSummary?
    var hasEnoughData: Bool = false

    func compute(readings: [MeterReading]) {
        let calendar = Calendar.current

        // Filter by selected meter type
        let filtered = readings
            .filter { $0.meterType == selectedType.rawValue }
            .filter { $0.date != nil && $0.value != nil }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        // Apply time range filter
        let cutoffDate: Date? = {
            guard let months = timeRange.months else { return nil }
            return calendar.date(byAdding: .month, value: -months, to: Date())
        }()

        let rangeFiltered: [MeterReading]
        if let cutoff = cutoffDate {
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

        // Group by calendar period
        let grouped = Dictionary(grouping: consumptions) { item -> Date in
            switch grouping {
            case .week:
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: item.date)
                return calendar.date(from: comps) ?? item.date
            case .month:
                let comps = calendar.dateComponents([.year, .month], from: item.date)
                return calendar.date(from: comps) ?? item.date
            }
        }

        // Sum per group and create data points
        let dateFormatter = DateFormatter()
        let points = grouped.map { (key, items) -> ConsumptionDataPoint in
            let total = items.reduce(0) { $0 + $1.value }
            let label: String
            switch grouping {
            case .week:
                let weekNum = calendar.component(.weekOfYear, from: key)
                label = "KW\(weekNum)"
            case .month:
                dateFormatter.dateFormat = "MMM yy"
                label = dateFormatter.string(from: key)
            }
            return ConsumptionDataPoint(label: label, value: total, date: key)
        }
        .sorted { $0.date < $1.date }

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
}
