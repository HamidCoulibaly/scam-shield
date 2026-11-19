// Downloads the daily list, checks it against its .sha256 file, saves it, reloads iOS.
import BackgroundTasks
import CallKit
import CryptoKit
import Foundation

enum UpdateError: LocalizedError {
    case http(Int), checksum
    var errorDescription: String? {
        switch self {
        case .http(let code): return "Download failed (HTTP \(code)). Will retry later."
        case .checksum: return "List didn't match its checksum (GitHub may still be updating). Kept the previous list."
        }
    }
}

enum Updater {
    static var listURL: URL {
        URL(string: Bundle.main.object(forInfoDictionaryKey: "ScamListURL") as? String ?? "")!
    }

    @discardableResult
    static func update() async throws -> ScamList {
        let session = URLSession(configuration: .ephemeral)            // no stale cache
        let (data, r1) = try await session.data(from: listURL)
        try check(r1)
        let (hashData, r2) = try await session.data(from: listURL.appendingPathExtension("sha256"))
        try check(r2)

        let expected = String(decoding: hashData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard expected == actual else { throw UpdateError.checksum }

        let list = try JSONDecoder().decode(ScamList.self, from: data)
        try data.write(to: Shield.listFile, options: .atomic)
        await ContactsSync.sync()                                      // pick up new contacts daily
        try await reloadExtension()
        Shield.defaults.set(Date(), forKey: "lastUpdate")
        Shield.defaults.removeObject(forKey: "lastError")
        return list
    }

    static func reloadExtension() async throws {
        try await CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: Shield.extensionID)
    }

    static func isEnabled() async -> Bool {
        let status = try? await CXCallDirectoryManager.sharedInstance.enabledStatusForExtension(withIdentifier: Shield.extensionID)
        return status == .enabled
    }

    private static func check(_ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw UpdateError.http(code) }
    }
}

enum DailyRefresh {
    static let id = "com.hamidcoulibaly.scamshield.refresh"

    /// Ask iOS to wake the app in ~12h. iOS decides the exact time (usually overnight on charge).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        do { try await Updater.update() } catch {
            Shield.defaults.set(error.localizedDescription, forKey: "lastError")
        }
    }
}
