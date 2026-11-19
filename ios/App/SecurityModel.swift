import Contacts
import LocalAuthentication
import Observation
import SwiftUI

/// Checks the app can do live, without asking you.
enum CheckKind: String {
    case scamShield, contacts, dnsFiltering, passcode, domains
}

struct SetupItem: Identifiable {
    let id: String
    let title: String
    let why: String
    var steps: [String] = []
    var link: URL? = nil
    var linkTitle: String = "Open"
    var auto: CheckKind? = nil
}

struct SetupArea: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let items: [SetupItem]
}

// MARK: - What to set up (from your runbook)

enum Catalog {
    static func area(_ id: String) -> SetupArea? { areas.first { $0.id == id } }

    static let areas: [SetupArea] = [
        SetupArea(id: "calls", title: "Calls & texts", subtitle: "Stop scam calls and texts",
                  symbol: "phone.fill", tint: .shieldAccent, items: [
            SetupItem(id: "calls.shield", title: "Scam Shield call blocking",
                      why: "Blocks and labels numbers on your daily scam list before the phone rings.",
                      steps: ["Tap Open Settings.", "Phone > Call Blocking & Identification.", "Turn on Scam Shield."],
                      auto: .scamShield),
            SetupItem(id: "calls.contacts", title: "Protect your contacts",
                      why: "Your contacts are never blocked, even if a number appears on a scam list.",
                      steps: ["Tap Open Settings.", "Contacts > Full Access."],
                      auto: .contacts),
            SetupItem(id: "calls.silence", title: "Silence unknown callers",
                      why: "Numbers not in your contacts go straight to voicemail. Most scam calls never ring.",
                      steps: ["Settings > Apps > Phone.", "Turn on Silence Unknown Callers."]),
            SetupItem(id: "calls.texts", title: "Filter unknown senders",
                      why: "Texts from unknown numbers go to a separate list, away from your main inbox.",
                      steps: ["Settings > Apps > Messages.", "Turn on Filter Unknown Senders."]),
            SetupItem(id: "calls.tps", title: "Register with TPS",
                      why: "Free UK register that legally stops UK companies cold-calling you.",
                      steps: ["Register your mobile, and your landline if you have one."],
                      link: URL(string: "https://www.tpsonline.org.uk"), linkTitle: "Open TPS"),
            SetupItem(id: "calls.7726", title: "Report scam texts to 7726",
                      why: "Free. Your network uses the reports to block the sender for everyone.",
                      steps: ["Long-press the scam text > More > Forward.", "Send it to 7726.",
                              "Then add the number in the Calls tab."]),
        ]),
        SetupArea(id: "email", title: "Email", subtitle: "Stop phishing and impersonation",
                  symbol: "envelope.fill", tint: .blue, items: [
            SetupItem(id: "email.domains", title: "Your domains can't be faked",
                      why: "SPF, DKIM and DMARC stop criminals sending emails that appear to come from you.",
                      steps: ["Tap View domain checks.", "Fix anything red from your Mac: python3 domain_watchdog.py plan, then apply."],
                      auto: .domains),
            SetupItem(id: "email.google", title: "Secure your Google account",
                      why: "Gmail (kamalekro@gmail.com) is the key to your other accounts.",
                      steps: ["Run Security Checkup.", "Add a passkey.", "Remove apps and devices you don't recognise."],
                      link: URL(string: "https://myaccount.google.com/security-checkup"), linkTitle: "Security Checkup"),
            SetupItem(id: "email.unsubscribe", title: "Clear marketing email in Gmail",
                      why: "Fewer senders means fewer places your address can leak from.",
                      steps: ["In Gmail, open Manage subscriptions.", "Unsubscribe from genuine companies.",
                              "Use Report spam (not unsubscribe) for anything suspicious."],
                      link: URL(string: "https://mail.google.com"), linkTitle: "Open Gmail"),
            SetupItem(id: "email.m365mfa", title: "Microsoft 365: Security Defaults",
                      why: "Forces two-factor sign-in on both Afriq mailboxes, for free.",
                      steps: ["Entra admin > Identity > Overview > Properties.", "Manage security defaults > Enabled."],
                      link: URL(string: "https://entra.microsoft.com"), linkTitle: "Open Entra"),
            SetupItem(id: "email.m365bulk", title: "Microsoft 365: junk bulk mail",
                      why: "Sends marketing emails to Junk for hamid.coulibaly@ and contact@.",
                      steps: ["Defender > Anti-spam policies > Default policy.", "Set Bulk email threshold to 5."],
                      link: URL(string: "https://security.microsoft.com/antispam"), linkTitle: "Open Defender"),
            SetupItem(id: "email.hostinger", title: "Hostinger: two-factor sign-in",
                      why: "Protects hPanel, your DNS and hamid@hamidcoulibaly.com.",
                      steps: ["hPanel > Account > Security.", "Turn on two-factor authentication."],
                      link: URL(string: "https://hpanel.hostinger.com"), linkTitle: "Open hPanel"),
            SetupItem(id: "email.hibp", title: "Breach alerts",
                      why: "Get an email when any of your addresses appears in a data breach.",
                      steps: ["Add kamalekro@gmail.com and hamid@hamidcoulibaly.com.",
                              "Use Domain search for afriqconsulting.com."],
                      link: URL(string: "https://haveibeenpwned.com/NotifyMe"), linkTitle: "Open HIBP"),
        ]),
        SetupArea(id: "home", title: "Home network", subtitle: "Broadband, Wi-Fi and filtering",
                  symbol: "wifi.router.fill", tint: .indigo, items: [
            SetupItem(id: "home.nextdns", title: "Block dangerous sites (NextDNS)",
                      why: "Blocks phishing and malware sites on this iPhone, on Wi-Fi and 4G.",
                      steps: ["Create a free NextDNS profile with Threat Intelligence on.",
                              "Install its configuration profile on this iPhone.",
                              "Settings > General > VPN & Device Management > install."],
                      link: URL(string: "https://my.nextdns.io"), linkTitle: "Open NextDNS",
                      auto: .dnsFiltering),
            SetupItem(id: "home.router", title: "Secure the Virgin Hub",
                      why: "The router admin page controls every device in the house.",
                      steps: ["Connect to home Wi-Fi and open the Hub page.", "Change the admin password.",
                              "Turn off WPS and UPnP.", "Use WPA2/WPA3 with a long Wi-Fi password."],
                      link: URL(string: "http://192.168.0.1"), linkTitle: "Open Hub"),
            SetupItem(id: "home.iot", title: "Separate network for smart devices",
                      why: "If a TV or smart plug is hacked, it can't reach your laptop or phone.",
                      steps: ["Turn on the guest network on the router.", "Move TVs, speakers and smart plugs onto it."]),
            SetupItem(id: "home.switch", title: "Broadband switch checklist",
                      why: "Set up the new router properly on day one.",
                      steps: ["Choose a router that allows custom DNS, guest Wi-Fi and modem mode.",
                              "New admin password, WPA3, WPS and UPnP off.",
                              "Ask about free scam-call protection on the landline.",
                              "Then add a Firewalla box for alerts on every device."]),
        ]),
        SetupArea(id: "devices", title: "Devices", subtitle: "iPhone, iPad and Mac",
                  symbol: "laptopcomputer.and.iphone", tint: .orange, items: [
            SetupItem(id: "devices.passcode", title: "Passcode on this iPhone",
                      why: "Without a passcode, anyone holding the phone has your email and banking.",
                      steps: ["Settings > Face ID & Passcode > Turn Passcode On."],
                      auto: .passcode),
            SetupItem(id: "devices.stolen", title: "Stolen Device Protection",
                      why: "A thief who learns your passcode still can't change your Apple Account.",
                      steps: ["Settings > Face ID & Passcode.", "Turn on Stolen Device Protection."]),
            SetupItem(id: "devices.updates", title: "Automatic updates everywhere",
                      why: "Most hacks use bugs that were already fixed.",
                      steps: ["iPhone and iPad: Settings > General > Software Update > Automatic Updates: all on.",
                              "Mac: System Settings > General > Software Update > Automatic updates: all on."]),
            SetupItem(id: "devices.mac", title: "Mac: FileVault and firewall",
                      why: "Encrypts the Mac if it's lost, and blocks unwanted incoming connections.",
                      steps: ["System Settings > Privacy & Security > FileVault: On.",
                              "System Settings > Network > Firewall: On, with stealth mode."]),
            SetupItem(id: "devices.backup", title: "Mac backups",
                      why: "Protects you against ransomware and a dead disk.",
                      steps: ["Time Machine to an external disk you unplug after.", "Keep iCloud backup on too."]),
            SetupItem(id: "devices.ipad", title: "iPads: same settings",
                      why: "Each iPad needs its own passcode, updates and Stolen Device Protection.",
                      steps: ["Repeat the passcode, updates and Stolen Device Protection steps on each iPad."]),
        ]),
        SetupArea(id: "accounts", title: "Accounts", subtitle: "Passwords and sign-in",
                  symbol: "person.badge.key.fill", tint: .purple, items: [
            SetupItem(id: "accounts.apple", title: "Apple Account check-up",
                      why: "Your Apple Account unlocks every Apple device and your iCloud data.",
                      steps: ["Settings > your name > Sign-In & Security.", "Check two-factor is on.",
                              "Remove devices you don't recognise."]),
            SetupItem(id: "accounts.passwords", title: "Fix weak and reused passwords",
                      why: "One leaked password shouldn't open other accounts.",
                      steps: ["Open the Passwords app > Security.", "Change every reused or compromised password."]),
            SetupItem(id: "accounts.adp", title: "Advanced Data Protection",
                      why: "End-to-end encrypts iCloud backups, photos and notes.",
                      steps: ["Set up a recovery contact or recovery key first.",
                              "Settings > your name > iCloud > Advanced Data Protection > On."]),
        ]),
    ]
}

// MARK: - State

@MainActor
@Observable
final class SecurityModel {
    static let defaultDomains = ["hamidcoulibaly.com", "afriqconsulting.com", "hamidcoulibaly.co.uk"]

    var done: Set<String> = Set(Shield.defaults.stringArray(forKey: "doneItems") ?? [])
    var auto: [CheckKind: Status] = [:]
    var domainNames: [String] = Shield.defaults.stringArray(forKey: "domains") ?? SecurityModel.defaultDomains
    var domains: [DomainReport] = []
    var checking = false
    var lastChecked: Date?

    func status(_ item: SetupItem) -> Status {
        if let kind = item.auto { return auto[kind] ?? .unknown }
        return done.contains(item.id) ? .good : .todo
    }

    var allItems: [SetupItem] { Catalog.areas.flatMap { $0.items } }

    var goodCount: Int { allItems.filter { status($0) == .good }.count }

    var score: Double {
        let total = allItems.count
        return total == 0 ? 0 : Double(goodCount) / Double(total)
    }

    func progress(_ area: SetupArea) -> (done: Int, total: Int) {
        (area.items.filter { status($0) == .good }.count, area.items.count)
    }

    /// Most urgent first: red, then amber, then anything not done.
    var nextStep: (area: SetupArea, item: SetupItem)? {
        let open = Catalog.areas.flatMap { a in a.items.map { (a, $0) } }.filter { status($0.1) != .good }
        return open.max { status($0.1).severity < status($1.1).severity }
            .map { (area: $0.0, item: $0.1) }
    }

    func toggle(_ item: SetupItem) {
        if done.contains(item.id) { done.remove(item.id) } else { done.insert(item.id) }
        Shield.defaults.set(Array(done), forKey: "doneItems")
    }

    func addDomain(_ raw: String) {
        let d = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard d.contains("."), !domainNames.contains(d) else { return }
        domainNames.append(d)
        saveDomains()
    }

    func removeDomains(at offsets: IndexSet) {
        domainNames.remove(atOffsets: offsets)
        saveDomains()
    }

    private func saveDomains() {
        Shield.defaults.set(domainNames, forKey: "domains")
        Task { await refresh() }
    }

    func refresh() async {
        checking = true
        defer { checking = false }

        async let shield = Updater.isEnabled()
        async let dns = DNSFilterCheck.run()
        async let reports = DomainCheck.runAll(domainNames)

        let contactsOK = CNContactStore.authorizationStatus(for: .contacts) == .authorized
        let passcodeOK = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

        auto[.contacts] = contactsOK ? .good : .bad
        auto[.passcode] = passcodeOK ? .good : .bad
        auto[.scamShield] = await shield ? .good : .bad
        auto[.dnsFiltering] = await dns
        domains = await reports
        auto[.domains] = domains.map { $0.status }.worst
        lastChecked = .now
    }
}
