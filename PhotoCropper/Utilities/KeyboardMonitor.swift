//
//  KeyboardMonitor.swift
//  PhotoCropper
//
//  Global keyboard monitor for hotkeys
//

import AppKit
import Combine

/// Monitor for global keyboard events (specifically Space and Enter keys)
///
/// This class monitors keyboard events both locally (when app is focused)
/// and globally (even when app is not focused), allowing for system-wide hotkeys.
///
/// ## Supported Keys
/// - **Space** (keyCode 49): Toggle composition overlays
/// - **Enter** (keyCode 36): Confirm actions
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
    }
    
    // MARK: - Properties
    
    /// Local event monitor (active when app is focused)
    private var localMonitor: Any?
    
    /// Global event monitor (active even when app is not focused)
    private var globalMonitor: Any?
    
    /// Callback triggered when Space key is pressed
    var onSpacePressed: (() -> Void)?
    
    /// Callback triggered when Enter key is pressed
    var onEnterPressed: (() -> Void)?
    
    /// Flag indicating if monitoring is active
    private(set) var isMonitoring: Bool = false
    
    // MARK: - Lifecycle
    
    /// Starts monitoring keyboard events
    ///
    /// Sets up both local and global event monitors for Space and Enter keys.
    /// Call this when you want to begin receiving keyboard events.
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ KeyboardMonitor: Already monitoring")
            return
        }
        
        // Local Monitor (when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event, isGlobal: false)
        }
        
        // Global Monitor (even when app is not focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, isGlobal: true)
        }
        
        isMonitoring = true
    }
    
    /// Stops monitoring keyboard events
    ///
    /// Removes all event monitors. Call this when you no longer need keyboard monitoring.
    func stopMonitoring() {
        guard isMonitoring else {
            return
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        isMonitoring = false
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Event Handling
    
    /// Handles keyboard events
    ///
    /// - Parameters:
    ///   - event: The keyboard event
    ///   - isGlobal: Whether this is a global or local event
    /// - Returns: The event to pass through, or `nil` to consume it (local events only)
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent, isGlobal: Bool) -> NSEvent? {
        switch event.keyCode {
        case KeyCode.space:
            onSpacePressed?()
            return isGlobal ? event : nil  // Consume local events
            
        case KeyCode.enter:
            onEnterPressed?()
            return isGlobal ? event : nil  // Consume local events
            
        default:
            return event  // Pass through other keys
        }
    }
}
