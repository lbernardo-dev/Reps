import Foundation
import WatchConnectivity

enum WatchCommandRouter {
    static func send(_ command: String) {
        guard WCSession.isSupported() else { return }
        let message = ["command": command]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}
