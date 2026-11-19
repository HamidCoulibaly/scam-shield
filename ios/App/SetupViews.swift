import CallKit
import SwiftUI
import UIKit

struct SetupView: View {
    @Environment(SecurityModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Catalog.areas) { area in
                        NavigationLink(value: area.id) {
                            HStack(spacing: 14) {
                                Image(systemName: area.symbol)
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(area.tint.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(area.title).font(.body.weight(.medium))
                                    Text(area.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                let p = model.progress(area)
                                Text("\(p.done)/\(p.total)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(p.done == p.total ? .green : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } footer: {
                    Text("Green items are checked live by the app or marked done by you. Pull down to re-check.")
                }
            }
            .navigationTitle("Setup")
            .navigationDestination(for: String.self) { id in AreaDetailView(areaID: id) }
            .refreshable { await model.refresh() }
        }
    }
}

struct AreaDetailView: View {
    @Environment(SecurityModel.self) private var model
    let areaID: String

    var body: some View {
        if let area = Catalog.area(areaID) {
            List {
                Section {
                    ForEach(area.items) { item in ItemRow(item: item) }
                } header: {
                    let p = model.progress(area)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(area.subtitle)
                        ProgressView(value: Double(p.done), total: Double(max(p.total, 1))).tint(area.tint)
                    }
                    .textCase(nil)
                    .padding(.bottom, 4)
                }
            }
            .navigationTitle(area.title)
            .refreshable { await model.refresh() }
        } else {
            ContentUnavailableView("Not found", systemImage: "questionmark")
        }
    }
}

struct ItemRow: View {
    @Environment(SecurityModel.self) private var model
    let item: SetupItem
    @State private var expanded = false

    private var status: Status { model.status(item) }

    private var statusText: String {
        switch status {
        case .good: return item.auto == nil ? "Done" : "Checked: OK"
        case .warn: return "Needs attention"
        case .bad: return item.auto == nil ? "To do" : "Checked: not set up"
        case .todo: return "To do"
        case .unknown: return item.auto == nil ? "To do" : "Couldn't check"
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.why).font(.subheadline).foregroundStyle(.secondary)
                if !item.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.shieldAccent))
                                Text(step).font(.subheadline)
                            }
                        }
                    }
                }
                if item.auto == .domains {
                    NavigationLink { DomainsView() } label: {
                        Label("View domain checks", systemImage: "globe")
                    }
                }
                actions
            }
            .padding(.vertical, 6)
        } label: {
            HStack(spacing: 12) {
                StatusIcon(status: status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.body.weight(.medium))
                    Text(statusText).font(.caption).foregroundStyle(status == .todo ? Color.secondary : status.color)
                }
            }
        }
        .sensoryFeedback(.success, trigger: status) { _, new in new == .good }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 10) {
            switch item.auto {
            case .scamShield?:
                Button("Open Settings") { CXCallDirectoryManager.sharedInstance.openSettings { _ in } }
                    .buttonStyle(.borderedProminent)
            case .contacts?:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.borderedProminent)
            default:
                if let link = item.link {
                    Link(destination: link) { Label(item.linkTitle, systemImage: "arrow.up.right.square") }
                        .buttonStyle(.bordered)
                }
            }
            if item.auto == nil {
                Button(model.done.contains(item.id) ? "Mark as to do" : "Mark done") {
                    withAnimation { model.toggle(item) }
                }
                .buttonStyle(.borderedProminent)
                .tint(model.done.contains(item.id) ? Color.gray : Color.shieldAccent)
            } else {
                Button("Re-check") { Task { await model.refresh() } }
                    .buttonStyle(.bordered)
            }
        }
    }
}

struct DomainsView: View {
    @Environment(SecurityModel.self) private var model
    @State private var newDomain = ""

    var body: some View {
        List {
            ForEach(model.domains) { report in
                Section {
                    ForEach(Array(report.findings.enumerated()), id: \.offset) { _, finding in
                        Label {
                            Text(finding.1).font(.subheadline)
                        } icon: {
                            Image(systemName: finding.0.symbol).foregroundStyle(finding.0.color)
                        }
                    }
                } header: {
                    HStack {
                        Text(report.domain).textCase(nil).font(.headline)
                        Spacer()
                        Text(report.receivesMail ? "sends email" : "no email").textCase(nil)
                    }
                }
            }

            Section {
                ForEach(model.domainNames, id: \.self) { Text($0) }
                    .onDelete { model.removeDomains(at: $0) }
                HStack {
                    TextField("Add a domain, e.g. example.com", text: $newDomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(add)
                    Button("Add", action: add).disabled(newDomain.isEmpty)
                }
            } header: {
                Text("Domains to watch")
            } footer: {
                Text("To fix anything red or amber, on your Mac run: cd ~/Downloads/domain-watchdog && python3 domain_watchdog.py plan, then apply.")
            }
        }
        .navigationTitle("Email domains")
        .refreshable { await model.refresh() }
        .overlay {
            if model.domains.isEmpty && model.checking { ProgressView("Checking DNS…") }
        }
    }

    private func add() {
        model.addDomain(newDomain)
        newDomain = ""
    }
}
