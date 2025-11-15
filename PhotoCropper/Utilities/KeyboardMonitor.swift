//
//  KeyboardMonitor.swift
//  PhotoCropper
//
//  Global Keyboard Monitor für Leertaste
//

import AppKit
import Combine

/// Monitor für globale Tastatur-Events (speziell Leertaste und Enter)
class KeyboardMonitor: ObservableObject {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    var onSpacePressed: (() -> Void)?
    var onEnterPressed: (() -> Void)?
    
    func startMonitoring() {
        print("🎯 KeyboardMonitor: Starte Monitoring...")
        
        // Local Monitor (wenn App aktiv ist)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("⌨️ Local Key Event: keyCode=\(event.keyCode), characters='\(event.characters ?? "")'")
            
            // Leertaste hat keyCode 49
            if event.keyCode == 49 {
                print("✅ Leertaste erkannt (keyCode 49)")
                self?.onSpacePressed?()
                return nil  // Event konsumieren
            }
            
            // Enter/Return hat keyCode 36
            if event.keyCode == 36 {
                print("✅ Enter erkannt (keyCode 36)")
                self?.onEnterPressed?()
                return nil  // Event konsumieren
            }
            
            return event
        }
        
        // Global Monitor (auch wenn App nicht im Fokus)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("🌍 Global Key Event: keyCode=\(event.keyCode)")
            
            if event.keyCode == 49 {
                print("✅ Leertaste erkannt (global)")
                self?.onSpacePressed?()
            }
            
            if event.keyCode == 36 {
                print("✅ Enter erkannt (global)")
                self?.onEnterPressed?()
            }
        }
        
        print("✅ KeyboardMonitor: Monitoring gestartet")
    }
    
    func stopMonitoring() {
        print("🛑 KeyboardMonitor: Stoppe Monitoring...")
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        print("✅ KeyboardMonitor: Monitoring gestoppt")
    }
    
    deinit {
        stopMonitoring()
    }
}

