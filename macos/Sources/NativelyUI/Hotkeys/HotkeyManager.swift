import Foundation
import Carbon.HIToolbox

/// Global Hotkey actions supported by the Natively Overlay.
public enum HotkeyAction: UInt32, CaseIterable, Sendable {
    case toggleVisibility = 1001          // Cmd+B
    case toggleMousePassthrough = 1002    // Cmd+Shift+B
    case toggleStealthFocus = 1003        // Cmd+Shift+Space
    case captureAndAsk = 1004             // Cmd+Shift+Enter
    case processScreenshots = 1005        // Cmd+Enter
    case triggerCrop = 1006               // Cmd+Shift+X or Cmd+Shift+H
    
    // Quick Action Presets (Cmd+1 through Cmd+7)
    case quickAction1 = 1011              // What to Answer
    case quickAction2 = 1012              // Clarify
    case quickAction3 = 1013              // Recap / Brainstorm
    case quickAction4 = 1014              // Follow Up
    case quickAction5 = 1015              // Answer / Record
    case quickAction6 = 1016              // Code Hint
    case quickAction7 = 1017              // Brainstorm Approaches
    
    // Window micro-nudges (Cmd+Shift+Arrows)
    case nudgeUp = 1021
    case nudgeDown = 1022
    case nudgeLeft = 1023
    case nudgeRight = 1024
}

/// Global Hotkey Manager using Carbon EventHotKeys for zero-accessibility-permission global shortcuts.
@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [HotkeyAction: @MainActor () -> Void] = [:]
    
    private init() {
        installCarbonHandler()
    }
    
    /// Register a callback for a specific HotkeyAction.
    public func onAction(_ action: HotkeyAction, perform: @escaping @MainActor () -> Void) {
        callbacks[action] = perform
    }
    
    /// Register all default Natively hotkeys.
    public func registerDefaultHotkeys() {
        unregisterAll()
        
        // Modifiers
        let cmd = UInt32(cmdKey)
        let cmdShift = UInt32(cmdKey | shiftKey)
        
        // Core Overlay Controls
        register(action: .toggleVisibility, keyCode: UInt32(kVK_ANSI_B), modifiers: cmd)
        register(action: .toggleMousePassthrough, keyCode: UInt32(kVK_ANSI_B), modifiers: cmdShift)
        register(action: .toggleStealthFocus, keyCode: UInt32(kVK_Space), modifiers: cmdShift)
        register(action: .processScreenshots, keyCode: UInt32(kVK_Return), modifiers: cmd)
        register(action: .captureAndAsk, keyCode: UInt32(kVK_Return), modifiers: cmdShift)
        register(action: .triggerCrop, keyCode: UInt32(kVK_ANSI_X), modifiers: cmdShift)
        
        // Quick Action Presets (Cmd+1 .. Cmd+7)
        register(action: .quickAction1, keyCode: UInt32(kVK_ANSI_1), modifiers: cmd)
        register(action: .quickAction2, keyCode: UInt32(kVK_ANSI_2), modifiers: cmd)
        register(action: .quickAction3, keyCode: UInt32(kVK_ANSI_3), modifiers: cmd)
        register(action: .quickAction4, keyCode: UInt32(kVK_ANSI_4), modifiers: cmd)
        register(action: .quickAction5, keyCode: UInt32(kVK_ANSI_5), modifiers: cmd)
        register(action: .quickAction6, keyCode: UInt32(kVK_ANSI_6), modifiers: cmd)
        register(action: .quickAction7, keyCode: UInt32(kVK_ANSI_7), modifiers: cmd)
        
        // Micro-nudges (Cmd+Shift+Arrows)
        register(action: .nudgeUp, keyCode: UInt32(kVK_UpArrow), modifiers: cmdShift)
        register(action: .nudgeDown, keyCode: UInt32(kVK_DownArrow), modifiers: cmdShift)
        register(action: .nudgeLeft, keyCode: UInt32(kVK_LeftArrow), modifiers: cmdShift)
        register(action: .nudgeRight, keyCode: UInt32(kVK_RightArrow), modifiers: cmdShift)
    }
    
    /// Register a specific hotkey
    public func register(action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E415456), id: action.rawValue) // "NATV"
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let hotKeyRef {
            hotKeyRefs[action.rawValue] = hotKeyRef
        }
    }
    
    /// Unregister all active hotkeys
    public func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
    
    /// Triggers the callback registered for an action (can also be invoked programmatically)
    public func triggerAction(_ action: HotkeyAction) {
        callbacks[action]?()
    }
    
    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData, let eventRef else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr, let action = HotkeyAction(rawValue: hotKeyID.id) {
                    DispatchQueue.main.async {
                        manager.triggerAction(action)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )
    }
}
