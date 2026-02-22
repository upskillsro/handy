import AppKit
import Foundation

@MainActor
final class AppWindowCoordinator: ObservableObject {
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("focus.main.window")
    static let pillWindowIdentifier = NSUserInterfaceItemIdentifier("focus.pill.window")
    
    weak var mainWindow: NSWindow?
    weak var pillWindow: NSWindow?
    var hasPrewarmedPillWindow = false
}
