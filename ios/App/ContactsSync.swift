// Reads phone numbers from Contacts so they are never blocked.
// The numbers are stored only in the app's private container on this iPhone.
import Contacts
import Foundation

enum ContactsSync {
    /// Returns how many contact numbers are protected, or nil if Contacts access isn't granted.
    @discardableResult
    static func sync() async -> Int? {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            guard (try? await store.requestAccess(for: .contacts)) == true else { return nil }
        } else if status != .authorized {
            return nil          // denied, restricted, or "limited" (only some contacts shared)
        }

        // Enumerating contacts is blocking work: keep it off the main thread.
        let numbers: Set<Int64> = await Task.detached(priority: .utility) {
            var found = Set<Int64>()
            let request = CNContactFetchRequest(keysToFetch: [CNContactPhoneNumbersKey as CNKeyDescriptor])
            try? store.enumerateContacts(with: request) { contact, _ in
                for entry in contact.phoneNumbers {
                    if let n = PhoneNumber.normalise(entry.value.stringValue) { found.insert(n) }
                }
            }
            return found
        }.value

        guard let data = try? JSONEncoder().encode(numbers.sorted()) else { return nil }
        try? data.write(to: Shield.contactsFile, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return numbers.count
    }
}
