import AppKit
import Carbon.HIToolbox

/// Global keyboard shortcuts via the Carbon hot key API (works while other apps are frontmost).
@MainActor
final class HotKeys {
    struct Combo {
        let keyCode: UInt32
        let modifiers: UInt32
        let label: String
    }

    enum Action: UInt32, CaseIterable {
        case toggleLive = 1
        case translateArea
        case subtitleLog
        case trophies

        var combo: Combo {
            let ctrlOpt = UInt32(controlKey | optionKey)
            switch self {
            case .toggleLive: return Combo(keyCode: UInt32(kVK_ANSI_L), modifiers: ctrlOpt, label: "⌃⌥L")
            case .translateArea: return Combo(keyCode: UInt32(kVK_ANSI_T), modifiers: ctrlOpt, label: "⌃⌥T")
            case .subtitleLog: return Combo(keyCode: UInt32(kVK_ANSI_H), modifiers: ctrlOpt, label: "⌃⌥H")
            case .trophies: return Combo(keyCode: UInt32(kVK_ANSI_K), modifiers: ctrlOpt, label: "⌃⌥K")
            }
        }
    }

    static let shared = HotKeys()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    func register(_ action: Action, handler: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        handlers[action.rawValue] = handler
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x534C_4E53), id: action.rawValue)  // "SLNS"
        let status = RegisterEventHotKey(action.combo.keyCode, action.combo.modifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs.append(ref) }
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKeys.shared.fire(id) } }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
