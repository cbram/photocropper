//
//  KeyboardMonitor.swift
//  PhotoCropper
//
//  Keyboard monitor for the app's hotkeys
//

import AppKit
import Combine

/// Monitor for the app's keyboard hotkeys (Space and Enter)
///
/// Only events of this app are seen (local monitor), so the keys act only while
/// PhotoCropper is in the foreground.
///
/// ## Supported Keys
/// - **Space** (keyCode 49): Toggle composition overlays — not while a text field has focus
/// - **Enter** (keyCode 36): Confirm actions — also in text fields; Option+Enter in a
///   text field is passed through (line break in multi-line fields)
/// - **Escape** (keyCode 53): Ends text editing while a text field has focus
///
/// ## Usage Example
/// ```swift
/// let monitor = KeyboardMonitor()
/// monitor.onSpacePressed = {
///     print("Space pressed!")
/// }
/// monitor.startMonitoring()
/// ```
///
/// - Important: Remember to call `stopMonitoring()` when done to avoid memory leaks
class KeyboardMonitor: ObservableObject {

    // MARK: - Constants

    /// Key codes for monitored keys
    private enum KeyCode {
        static let space: UInt16 = 49
        static let enter: UInt16 = 36
        static let escape: UInt16 = 53
    }

    // MARK: - Properties

    /// Local event monitor (active when app is focused)
    private var localMonitor: Any?

    /// Callback triggered when Space key is pressed
    var onSpacePressed: (() -> Void)?

    /// Callback triggered when Enter key is pressed
    var onEnterPressed: (() -> Void)?

    /// Flag indicating if monitoring is active
    private(set) var isMonitoring: Bool = false

    // MARK: - Lifecycle

    /// Starts monitoring keyboard events
    ///
    /// Sets up the local event monitor for Space and Enter keys.
    /// Call this when you want to begin receiving keyboard events.
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ KeyboardMonitor: Already monitoring")
            return
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKeyEvent(event)
        }

        isMonitoring = true
    }

    /// Stops monitoring keyboard events
    ///
    /// Removes the event monitor. Call this when you no longer need keyboard monitoring.
    func stopMonitoring() {
        guard isMonitoring else {
            return
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        isMonitoring = false
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Event Handling

    /// Handles keyboard events
    ///
    /// - Parameter event: The keyboard event
    /// - Returns: The event to pass through, or `nil` to consume it
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Text fields edit through an NSText field editor
        let isEditingText = event.window?.firstResponder is NSText

        switch event.keyCode {
        case KeyCode.space where !isEditingText:
            onSpacePressed?()
            return nil

        case KeyCode.enter:
            // Option+Enter in a text field inserts a line break instead of confirming
            if isEditingText && event.modifierFlags.contains(.option) {
                return event
            }
            onEnterPressed?()
            return nil

        case KeyCode.escape where isEditingText:
            // End text editing (the typed value stays)
            event.window?.makeFirstResponder(nil)
            return nil

        default:
            return event  // Pass through other keys (including Space while typing)
        }
    }
}
