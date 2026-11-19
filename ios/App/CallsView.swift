import CallKit
import SwiftUI
import UIKit

struct CallsView: View {
    @Environment(SecurityModel.self) private var model
    @State private var enabled = false
    @State private var list = Store.loadList()
    @State private var reports = Store.loadReports()
    @State private var contactsProtected: Int?
    @State private var busy = false
    @State private var message: String?
    @State private var newNumber = ""
    @State private var newLabel = ""
    @FocusState private var numberFocused: Bool

    private var lastUpdate: String {
        guard let d = Shield.defaults.object(forKey: "lastUpdate") as? Date else { return "never" }
        return d.formatted(.relative(presentation: .named))
    }

    var body: some View {
        NavigationStack {
            List {
                Section { hero }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                Section {
                    TextField("Number, e.g. 07700 900123", text: $newNumber)
                        .keyboardType(.phonePad)
                        .focused($numberFocused)
                    TextField("What was it? e.g. Fake HMRC (optional)", text: $newLabel)
                    Button {
                        add()
                    } label: {
                        Label("Block this number", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(newNumber.isEmpty)
                } header: {
                    Text("Report a scam number")
                } footer: {
                    Text("Blocked on this phone straight away.")
                }

                if !reports.isEmpty {
                    Section {
                        ForEach(reports) { r in
                            HStack {
                                Image(systemName: "phone.down.fill").foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(PhoneNumber.pretty(r.number)).monospacedDigit()
                                    Text(r.label.isEmpty ? r.date.formatted(date: .abbreviated, time: .omitted)
                                                         : "\(r.label) · \(r.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: remove)
                        Button { copyForCollector() } label: {
                            Label("Copy for the shared list", systemImage: "doc.on.doc")
                        }
                    } header: {
                        Text("My reports (\(reports.count))")
                    } footer: {
                        Text("Swipe left to unblock. “Copy” gives you Terminal commands to add these to your daily list on GitHub.")
                    }
                }
            }
            .navigationTitle("Calls")
            .task { await refreshStatus() }
            .refreshable { await update() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { numberFocused = false }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: enabled ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(enabled ? Color.shieldAccent : Color.orange)
                .symbolEffect(.bounce, value: enabled)
            Text(enabled ? "Call protection is on" : "Call protection is off")
                .font(.title3.bold())
            if enabled {
                Text("List updated \(lastUpdate)").font(.footnote).foregroundStyle(.secondary)
            } else {
                Button("Turn on in Settings") { CXCallDirectoryManager.sharedInstance.openSettings { _ in } }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            HStack(spacing: 10) {
                StatTile(value: "\(list.block.count + reports.count)", label: "Blocked")
                StatTile(value: "\(list.identify.count)", label: "Labelled")
                StatTile(value: contactsProtected.map { "\($0)" } ?? "–", label: "Contacts safe")
            }
            Button {
                Task { await update() }
            } label: {
                Label(busy ? "Updating…" : "Update list now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(busy)
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            message = "Latest list loaded (\(list.version))."
        } catch {
            message = error.localizedDescription
        }
        enabled = await Updater.isEnabled()
        await model.refresh()
    }

    private func add() {
        guard let n = PhoneNumber.normalise(newNumber) else {
            message = "That doesn't look like a full number. Try 07700 900123 or +44…"
            return
        }
        if !reports.contains(where: { $0.number == n }) {
            withAnimation { reports.insert(MyReport(number: n, label: newLabel, date: .now), at: 0) }
        }
        save("Blocked \(PhoneNumber.pretty(n)).")
        newNumber = ""
        newLabel = ""
        numberFocused = false
    }

    private func remove(at offsets: IndexSet) {
        reports.remove(atOffsets: offsets)
        save("Unblocked.")
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

    private func copyForCollector() {
        UIPasteboard.general.string = reports.map { r in
            let label = r.label.replacingOccurrences(of: "\"", with: "'")
            return "python3 collector.py add \"+\(r.number)\"" + (label.isEmpty ? "" : " --label \"\(label)\"")
        }.joined(separator: "\n")
        message = "Copied \(reports.count) command(s). Paste them in Terminal inside scam-shield/collector, then git push."
    }
}
