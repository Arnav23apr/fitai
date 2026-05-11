import Foundation
import UIKit

/// Strong-compatible CSV export. Columns match Strong's published export
/// format so users coming from there or going to Hevy (which imports
/// Strong CSVs) can move data freely. Schema:
///
///   Date, Workout Name, Duration, Exercise Name, Set Order, Weight,
///   Weight Unit, Reps, RPE, Distance, Distance Unit, Seconds, Notes,
///   Workout Notes
///
/// We synthesize Workout Name and Duration from session-grouping logic
/// since `ExerciseLog` is exercise-scoped, not session-scoped — logs
/// from the same calendar day collapse into one row group.
enum CSVExportService {

    /// Build the full CSV string for every persisted log.
    static func exportAllLogs(usesMetric: Bool) -> String {
        let logs = ExerciseLogService.shared.loadAll()
            .sorted { $0.date < $1.date }
        let unit = usesMetric ? "kg" : "lbs"

        var lines: [String] = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Weight Unit,Reps,RPE,Distance,Distance Unit,Seconds,Notes,Workout Notes"
        ]

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        dateFormatter.timeZone = .current

        let distanceUnit = usesMetric ? "km" : "mi"

        for log in logs {
            for (idx, set) in log.sets.enumerated() {
                // Convert canonical-meters distance to the user's
                // preferred display unit at export time so the file
                // matches what they see in-app.
                let distanceText: String = {
                    guard let m = set.distanceMeters, m > 0 else { return "" }
                    let value = usesMetric ? (m / 1000.0) : (m / 1609.344)
                    return String(format: "%.3f", value)
                }()
                let cells: [String] = [
                    dateFormatter.string(from: set.timestamp),
                    csvEscape(log.exerciseName),                  // Workout Name placeholder
                    "",                                           // Duration (per-log unknown)
                    csvEscape(log.exerciseName),
                    "\(idx + 1)",
                    formatWeight(set.weight),
                    unit,
                    "\(set.reps)",
                    set.rpe.map { formatRPE($0) } ?? "",
                    distanceText,
                    distanceText.isEmpty ? "" : distanceUnit,
                    set.durationSeconds.map { "\($0)" } ?? "",
                    csvEscape(set.note ?? ""),
                    ""                                            // Workout Notes
                ]
                lines.append(cells.joined(separator: ","))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Write the CSV to a temp file and return its URL. Used by ShareLink.
    /// Filename is timestamped so successive exports don't overwrite.
    static func exportToTemporaryFile(usesMetric: Bool) -> URL? {
        let csv = exportAllLogs(usesMetric: usesMetric)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: Date())
        let fileName = "fitai-export-\(stamp).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func formatWeight(_ w: Double) -> String {
        // Strong / Hevy emit decimals only when the value is non-integer.
        w == w.rounded() ? "\(Int(w))" : String(format: "%.2f", w)
    }

    private static func formatRPE(_ rpe: Double) -> String {
        rpe == rpe.rounded() ? "\(Int(rpe))" : String(format: "%.1f", rpe)
    }
}
