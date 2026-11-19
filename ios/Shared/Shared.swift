// Code used by both the app and the call-blocking extension.
import Foundation

enum Shield {
    static let appGroup = "group.com.hamidcoulibaly.scamshield"
    static let extensionID = "com.hamidcoulibaly.scamshield.CallBlock"

    static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.temporaryDirectory
    }
    static var listFile: URL { container.appendingPathComponent("scamlist.json") }
    static var reportsFile: URL { container.appendingPathComponent("my_reports.json") }
    /// Numbers from the phone's contacts. Written by the app, never leaves the phone.
    static var contactsFile: URL { container.appendingPathComponent("contacts_allow.json") }
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}

/// The list published by the collector: {"version": "...", "block": [...], "identify": [[n, "label"], ...]}
struct ScamList: Codable {
    var version: String
    var block: [Int64]
    var identify: [Labelled]

    struct Labelled: Codable {
        let number: Int64
        let label: String

        init(number: Int64, label: String) {
            self.number = number
            self.label = label
        }
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            number = try c.decode(Int64.self)
            label = try c.decode(String.self)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(number)
            try c.encode(label)
        }
    }

    static let empty = ScamList(version: "not downloaded yet", block: [], identify: [])
}

/// A number you reported from the phone. Always blocked.
struct MyReport: Codable, Identifiable, Equatable {
    var id: Int64 { number }
    let number: Int64
    let label: String
    let date: Date
}

enum Store {
    static func loadList() -> ScamList {
        guard let data = try? Data(contentsOf: Shield.listFile),
              let list = try? JSONDecoder().decode(ScamList.self, from: data) else { return .empty }
        return list
    }

    static func loadReports() -> [MyReport] {
        guard let data = try? Data(contentsOf: Shield.reportsFile),
              let list = try? JSONDecoder().decode([MyReport].self, from: data) else { return [] }
        return list
    }

    static func saveReports(_ reports: [MyReport]) throws {
        try JSONEncoder().encode(reports).write(to: Shield.reportsFile, options: .atomic)
    }

    static func loadContacts() -> Set<Int64> {
        guard let data = try? Data(contentsOf: Shield.contactsFile),
              let list = try? JSONDecoder().decode([Int64].self, from: data) else { return [] }
        return Set(list)
    }

    /// What iOS gets: both lists sorted ascending, no duplicates, a number in one list only.
    /// Your contacts are never blocked or labelled from the shared list.
    /// A number you reported yourself is always blocked, even if it is a contact.
    static func merged() -> (block: [Int64], identify: [(Int64, String)]) {
        let list = loadList()
        let contacts = loadContacts()
        var block = Set(list.block).subtracting(contacts)
        for r in loadReports() { block.insert(r.number) }
        var labels: [Int64: String] = [:]
        for e in list.identify where !block.contains(e.number) && !contacts.contains(e.number) {
            labels[e.number] = e.label
        }
        return (block.sorted(), labels.keys.sorted().map { ($0, labels[$0]!) })
    }
}

enum PhoneNumber {
    /// Same rules as collector.py: 07700 900123 / +44 7700 900123 / 0044... -> 447700900123
    static func normalise(_ raw: String) -> Int64? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let plus = text.hasPrefix("+")
        var digits = String(text.filter { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty else { return nil }
        if plus {
            // already international
        } else if digits.hasPrefix("00") {
            digits.removeFirst(2)
        } else if digits.hasPrefix("0") {
            digits = "44" + digits.dropFirst()
        } else if !digits.hasPrefix("44") {
            return nil
        }
        if digits.hasPrefix("44") {
            guard (11...12).contains(digits.count) else { return nil }
        } else {
            guard (8...15).contains(digits.count) else { return nil }
        }
        return Int64(digits)
    }

    static func pretty(_ n: Int64) -> String {
        let s = String(n)
        guard s.hasPrefix("44") else { return "+" + s }
        let local = "0" + s.dropFirst(2)
        let cut = local.hasPrefix("02") ? 3 : 5
        return String(local.prefix(cut)) + " " + String(local.dropFirst(cut))
    }
}
