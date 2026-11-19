// Runs when iOS asks for the list (after the app calls reloadExtension).
// iOS then blocks or labels these numbers itself; nothing runs during a call.
import CallKit
import Foundation

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Always send the full list: simpler and safe for lists this size.
        if context.isIncremental {
            context.removeAllBlockingEntries()
            context.removeAllIdentificationEntries()
        }

        let lists = Store.merged()
        for number in lists.block {
            autoreleasepool { context.addBlockingEntry(withNextSequentialPhoneNumber: number) }
        }
        for (number, label) in lists.identify {
            autoreleasepool { context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label) }
        }
        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        Shield.defaults.set("Extension error: \(error.localizedDescription)", forKey: "lastError")
    }
}
