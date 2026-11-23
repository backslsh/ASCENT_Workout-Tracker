import SwiftUI

struct SupersetInfo: Equatable {
    let label: String
    let color: Color
    let isFirst: Bool
    let isLast: Bool
}

private let supersetColors: [Color] = [Color(hex: 0x3FD5FF), Color(hex: 0xFFB547), Color(hex: 0x4BE3A0), Color(hex: 0xFF6B8B)]
private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

extension Array where Element == ExerciseEntry {
    /// Superset membership for an entry. Only contiguous runs of 2+ entries count.
    func supersetInfo(for id: UUID) -> SupersetInfo? {
        guard let i = firstIndex(where: { $0.id == id }), let g = self[i].supersetID else { return nil }
        var lo = i
        while lo > 0 && self[lo - 1].supersetID == g { lo -= 1 }
        var hi = i
        while hi < count - 1 && self[hi + 1].supersetID == g { hi += 1 }
        guard hi > lo else { return nil }

        var groupIndex = 0
        var j = 0
        while j < lo {
            if let gid = self[j].supersetID, j + 1 < count, self[j + 1].supersetID == gid {
                groupIndex += 1
                while j < count && self[j].supersetID == gid { j += 1 }
            } else {
                j += 1
            }
        }
        return SupersetInfo(label: "Superset \(letters[groupIndex % letters.count])",
                            color: supersetColors[groupIndex % supersetColors.count],
                            isFirst: i == lo, isLast: i == hi)
    }

    func canLinkWithNext(_ id: UUID) -> Bool {
        guard let i = firstIndex(where: { $0.id == id }), i + 1 < count else { return false }
        return self[i].supersetID == nil || self[i].supersetID != self[i + 1].supersetID
    }

    mutating func linkWithNext(_ id: UUID) {
        guard let i = firstIndex(where: { $0.id == id }), i + 1 < count else { return }
        let g = self[i].supersetID ?? UUID()
        let old = self[i + 1].supersetID
        self[i].supersetID = g
        if let old, old != g {
            for k in indices where self[k].supersetID == old { self[k].supersetID = g }
        } else {
            self[i + 1].supersetID = g
        }
        normalizeSupersets()
    }

    mutating func unlinkSuperset(_ id: UUID) {
        guard let i = firstIndex(where: { $0.id == id }) else { return }
        self[i].supersetID = nil
        normalizeSupersets()
    }

    /// Drops single-member groups and splits groups that are no longer contiguous (e.g. after reordering).
    mutating func normalizeSupersets() {
        var seen = Set<UUID>()
        var i = 0
        while i < count {
            guard let g = self[i].supersetID else { i += 1; continue }
            var j = i
            while j + 1 < count && self[j + 1].supersetID == g { j += 1 }
            if j == i {
                self[i].supersetID = nil
            } else if seen.contains(g) {
                let n = UUID()
                for k in i...j { self[k].supersetID = n }
                seen.insert(n)
            } else {
                seen.insert(g)
            }
            i = j + 1
        }
    }
}
