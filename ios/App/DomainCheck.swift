// Live email-security check for your domains, using public DNS over HTTPS.
// Same rules as domain_watchdog.py, so the app and the Mac script agree.
import Foundation

struct DomainReport: Identifiable, Sendable {
    var id: String { domain }
    let domain: String
    let receivesMail: Bool
    let spf: String?
    let dmarc: String?
    let dkimSelector: String?
    let lookupFailed: Bool

    var dmarcPolicy: String? {
        guard let dmarc else { return nil }
        for part in dmarc.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if kv.count == 2, kv[0] == "p" { return kv[1] }
        }
        return nil
    }

    /// Each finding: a status and one plain sentence.
    var findings: [(Status, String)] {
        if lookupFailed { return [(.unknown, "Couldn't reach DNS. Pull down to try again.")] }
        var out: [(Status, String)] = []
        let policy = dmarcPolicy

        if receivesMail {
            switch spf {
            case nil: out.append((.bad, "No SPF record: anyone can claim to send as this domain."))
            case let s? where s.contains("-all"): out.append((.good, "SPF is strict (-all)."))
            case let s? where s.contains("~all"): out.append((.warn, "SPF is soft (~all). Tighten to -all once DMARC reports are clean."))
            default: out.append((.warn, "SPF exists but doesn't end in -all or ~all."))
            }
            switch policy {
            case nil: out.append((.bad, "No DMARC: fake emails from this domain are not rejected."))
            case "reject"?: out.append((.good, "DMARC rejects fake emails (p=reject)."))
            case "quarantine"?: out.append((.good, "DMARC sends fakes to junk (p=quarantine). Next step: reject."))
            default: out.append((.warn, "DMARC only monitors (p=none). Move to quarantine, then reject."))
            }
            if let sel = dkimSelector {
                out.append((.good, "DKIM signing key published (\(sel))."))
            } else {
                out.append((.warn, "No DKIM key found on the usual selectors."))
            }
        } else {
            out.append((.good, "No mail servers, so this domain sends no email."))
            out.append(spf?.contains("-all") == true
                       ? (.good, "SPF blocks all senders (-all).")
                       : (.bad, "Unused domain without SPF -all: add v=spf1 -all."))
            out.append(policy == "reject"
                       ? (.good, "DMARC rejects everything (p=reject).")
                       : (.bad, "Unused domain without DMARC reject: add p=reject."))
        }
        return out
    }

    var status: Status { findings.map { $0.0 }.worst }
}

enum DomainCheck {
    private static let selectors = ["hostingermail-a", "selector1", "selector2", "google", "default", "k1", "s1"]

    static func runAll(_ names: [String]) async -> [DomainReport] {
        await withTaskGroup(of: DomainReport.self) { group in
            for name in names { group.addTask { await run(name) } }
            var reports: [DomainReport] = []
            for await r in group { reports.append(r) }
            return reports.sorted { (names.firstIndex(of: $0.domain) ?? 0) < (names.firstIndex(of: $1.domain) ?? 0) }
        }
    }

    static func run(_ domain: String) async -> DomainReport {
        async let mx = query(domain, "MX")
        async let txt = query(domain, "TXT")
        async let dmarc = query("_dmarc.\(domain)", "TXT")
        let (mxR, txtR, dmarcR) = await (mx, txt, dmarc)
        guard let mxR, let txtR, let dmarcR else {
            return DomainReport(domain: domain, receivesMail: false, spf: nil, dmarc: nil,
                                dkimSelector: nil, lookupFailed: true)
        }
        let receivesMail = mxR.contains { $0.trimmingCharacters(in: .whitespaces) != "0 ." }
        var dkim: String?
        if receivesMail {
            for sel in selectors {
                if let r = await query("\(sel)._domainkey.\(domain)", "TXT"),
                   r.contains(where: { $0.contains("p=") && !$0.hasSuffix("p=") }) {
                    dkim = sel
                    break
                }
            }
        }
        return DomainReport(
            domain: domain,
            receivesMail: receivesMail,
            spf: txtR.first { $0.lowercased().hasPrefix("v=spf1") },
            dmarc: dmarcR.first { $0.lowercased().hasPrefix("v=dmarc1") },
            dkimSelector: dkim,
            lookupFailed: false)
    }

    private struct DoH: Decodable {
        struct Answer: Decodable { let type: Int; let data: String }
        let answer: [Answer]?
        enum CodingKeys: String, CodingKey { case answer = "Answer" }
    }

    /// Returns the record values (quotes removed), [] if none, nil if the lookup failed.
    static func query(_ name: String, _ type: String) async -> [String]? {
        var comps = URLComponents(string: "https://dns.google/resolve")!
        comps.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "type", value: type)]
        guard let url = comps.url,
              let result = try? await URLSession(configuration: .ephemeral).data(from: url),
              let decoded = try? JSONDecoder().decode(DoH.self, from: result.0) else { return nil }
        let typeCode = type == "MX" ? 15 : 16
        return (decoded.answer ?? [])
            .filter { $0.type == typeCode }
            .map { $0.data.replacingOccurrences(of: "\" \"", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }
}

/// Is this iPhone's DNS going through NextDNS right now?
enum DNSFilterCheck {
    static func run() async -> Status {
        guard let url = URL(string: "https://test.nextdns.io") else { return .unknown }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let result = try? await URLSession(configuration: .ephemeral).data(for: request),
              let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let status = json["status"] as? String else { return .unknown }
        return status == "ok" ? .good : .bad
    }
}
