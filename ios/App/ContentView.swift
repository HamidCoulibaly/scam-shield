import CallKit
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var enabled = false
    @State private var list = Store.loadList()
    @State private var reports = Store.loadReports()
    @State private var busy = false
    @State private var message: String?
    @State private var newNumber = ""
    @State private var newLabel = ""
    @State private var contactsProtected: Int?

    private var lastUpdate: String {
        guard let d = Shield.defaults.object(forKey: "lastUpdate") as? Date else { return "never" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Protection") {
                    Label(enabled ? "On" : "Off: switch it on in Settings",
                          systemImage: enabled ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundStyle(enabled ? .green : .orange)
                    if !enabled {
                        Button("Open Settings") {
                            CXCallDirectoryManager.sharedInstance.openSettings { _ in }
                        }
                        Text("Settings > Apps > Phone > Call Blocking & Identification > turn on Scam Shield.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("Blocked", value: "\(list.block.count + reports.count)")
                    LabeledContent("Labelled", value: "\(list.identify.count)")
                    LabeledContent("Contacts protected",
                                   value: contactsProtected.map { "\($0) numbers" } ?? "no access")
                    if contactsProtected == nil {
                        Text("Allow Full Access to Contacts so your contacts are never blocked: Settings > Apps > Scam Shield > Contacts.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("Last update", value: lastUpdate)
                    Button(busy ? "Updating…" : "Update now") { Task { await update() } }
                        .disabled(busy)
                    if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }

                Section {
                    TextField("Number, e.g. 07700 900123", text: $newNumber)
                        .keyboardType(.phonePad)
                    TextField("What was it? (optional)", text: $newLabel)
                    Button("Block this number") { add() }
                        .disabled(newNumber.isEmpty)
                } header: {
                    Text("Report a scam number")
                } footer: {
                    Text("Blocked on this phone straight away. Use “Copy for collector” to add your reports to the shared list.")
                }

                if !reports.isEmpty {
                    Section("My reports") {
                        ForEach(reports) { r in
                            VStack(alignment: .leading) {
                                Text(PhoneNumber.pretty(r.number)).monospacedDigit()
                                if !r.label.isEmpty { Text(r.label).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .onDelete(perform: remove)
                        Button("Copy for collector") { copyForCollector() }
                    }
                }
            }
            .navigationTitle("Scam Shield")
            .task { await refreshStatus() }
            .refreshable { await update() }
        }
    }

    // MARK: actions

    private func refreshStatus() async {
        contactsProtected = await ContactsSync.sync()
        try? await Updater.reloadExtension()
        enabled = await Updater.isEnabled()
        list = Store.loadList()
        message = Shield.defaults.string(forKey: "lastError")
    }

    private func update() async {
        busy = true
        defer { busy = false }
        do {
            list = try await Updater.update()
            contactsProtected = await ContactsSync.sync()
            message = "List \(list.version) loaded."
        } catch {
            message = error.localizedDescription
        }
        enabled = await Updater.isEnabled()
    }

    private func add() {
        guard let n = PhoneNumber.normalise(newNumber) else {
            message = "That doesn't look like a full UK number. Try 07700 900123 or +44…"
            return
        }
        if !reports.contains(where: { $0.number == n }) {
            reports.insert(MyReport(number: n, label: newLabel, date: .now), at: 0)
        }
        save("Blocked \(PhoneNumber.pretty(n)).")
        newNumber = ""
        newLabel = ""
    }

    private func remove(at offsets: IndexSet) {
        reports.remove(atOffsets: offsets)
        save("Removed.")
    }

    private func save(_ done: String) {
        do {
            try Store.saveReports(reports)
            Task {
                do { try await Updater.reloadExtension(); message = done }
                catch { message = "Saved, but iOS didn't reload the list: \(error.localizedDescription)" }
            }
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }

    /// Terminal commands for the collector, so phone reports reach the shared daily list.
    private func copyForCollector() {
        UIPasteboard.general.string = reports.map { r in
            let label = r.label.replacingOccurrences(of: "\"", with: "'")
            return "python3 collector.py add \"+\(r.number)\"" + (label.isEmpty ? "" : " --label \"\(label)\"")
        }.joined(separator: "\n")
        message = "Copied \(reports.count) command(s). Paste them in Terminal in scam-shield/collector, then git push."
    }
}
