import Foundation

struct WidgetRoutine: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var exercises: Int
}

/// A tiny summary the app writes to the shared App Group container for the home-screen widget.
struct WidgetSnapshot: Codable, Equatable {
    var name: String
    var sessionDates: [Date]
    var weeklyGoal: Int
    var overallTitle: String?
    var overallColors: [UInt32]
    var overallSymbol: String?
    var overallProgress: Double
    var pinned: [WidgetRoutine]
    var accent: UInt32
    var accent2: UInt32
    var activeName: String?
    var activeStart: Date?

    static let appGroup = "group.com.ascend.fitness"

    static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let u = url, let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: d)
    }

    static let empty = WidgetSnapshot(name: "", sessionDates: [], weeklyGoal: 4, overallTitle: nil, overallColors: [],
                                      overallSymbol: nil, overallProgress: 0, pinned: [], accent: 0x8C7BFF,
                                      accent2: 0x3FD5FF, activeName: nil, activeStart: nil)

    static let sample = WidgetSnapshot(name: "Athlete",
                                       sessionDates: [Date(), Date().addingTimeInterval(-86400 * 2), Date().addingTimeInterval(-86400 * 8)],
                                       weeklyGoal: 4, overallTitle: "Gold II", overallColors: [0xFFE07A, 0xD99A1E],
                                       overallSymbol: "star.fill", overallProgress: 0.4,
                                       pinned: [WidgetRoutine(id: UUID(), name: "Push Day", exercises: 5),
                                                WidgetRoutine(id: UUID(), name: "Core Crusher", exercises: 4)],
                                       accent: 0x8C7BFF, accent2: 0x3FD5FF, activeName: nil, activeStart: nil)
}
