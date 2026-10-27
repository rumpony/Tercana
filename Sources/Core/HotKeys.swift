import AppKit
import Carbon.HIToolbox

/// Global keyboard shortcuts via the Carbon hot key API (works while other apps are frontmost).
@MainActor
final class HotKeys {
    struct Combo: Codable, Equatable {
        let keyCode: UInt32
        let modifiers: UInt32
        let label: String
    }

    enum Action: UInt32, CaseIterable {
        case toggleLive = 1
        case translateArea
        case subtitleLog
        case trophies

        var defaultCombo: Combo {
            let ctrlOpt = UInt32(controlKey | optionKey)
            switch self {
            case .toggleLive: return Combo(keyCode: UInt32(kVK_ANSI_L), modifiers: ctrlOpt, label: "⌃⌥L")
            case .translateArea: return Combo(keyCode: UInt32(kVK_ANSI_T), modifiers: ctrlOpt, label: "⌃⌥T")
            case .subtitleLog: return Combo(keyCode: UInt32(kVK_ANSI_H), modifiers: ctrlOpt, label: "⌃⌥H")
            case .trophies: return Combo(keyCode: UInt32(kVK_ANSI_K), modifiers: ctrlOpt, label: "⌃⌥K")
            }
        }

        private var defaultsKey: String { "hotkey.\(rawValue)" }

        /// The user's combo, or the default.
        var combo: Combo {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let saved = try? JSONDecoder().decode(Combo.self, from: data) else { return defaultCombo }
            return saved
        }

        func save(_ combo: Combo?) {
            if let combo, combo != defaultCombo, let data = try? JSONEncoder().encode(combo) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    static let shared = HotKeys()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    func register(_ action: Action, handler: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        handlers[action.rawValue] = handler
        bind(action)
    }

    /// Applies a new combo right away (nil restores the default).
    func change(_ action: Action, to combo: Combo?) {
        action.save(combo)
        bind(action)
    }

    /// Paused while recording a new shortcut, so pressing the current one doesn't fire it.
    func suspend(_ suspended: Bool) {
        for action in Action.allCases {
            if suspended {
                if let ref = refs.removeValue(forKey: action.rawValue) { UnregisterEventHotKey(ref) }
            } else if handlers[action.rawValue] != nil {
                bind(action)
            }
        }
    }

    private func bind(_ action: Action) {
        if let old = refs.removeValue(forKey: action.rawValue) { UnregisterEventHotKey(old) }
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x5452_434E), id: action.rawValue)  // "TRCN"
        let combo = action.combo
        if RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr,
           let ref {
            refs[action.rawValue] = ref
        }
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

extension HotKeys.Combo {
    /// Builds a combo from a key press; nil without a modifier (a bare letter would hijack typing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isEmpty, !flags.isSubset(of: [.shift]) else { return nil }
        var carbon: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !key.isEmpty else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbon, label: symbols + key)
    }
}
