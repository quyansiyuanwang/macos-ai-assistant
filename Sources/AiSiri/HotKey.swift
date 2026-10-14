import Carbon.HIToolbox
import AppKit

/// 全局热键（Carbon，无需辅助功能权限）。支持配置组合键。
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventRef: EventHandlerRef?
    var onPressed: (() -> Void)?

    func register(combo: String) {
        unregister()
        let (keyCode, modifiers) = HotKeyManager.parse(combo)
        guard let keyCode else { return }
        let signature: OSType = 0x41495352 // 'AISR'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, userData) -> OSStatus in
            guard let userData else { return noErr }
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { mgr.onPressed?() }
            return noErr
        }, 1, &eventType, selfPtr, &eventRef)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let r = hotKeyRef { UnregisterEventHotKey(r); hotKeyRef = nil }
        if let e = eventRef { RemoveEventHandler(e); eventRef = nil }
    }

    deinit { unregister() }

    /// 可选预设：(配置值, 显示名)
    static let presets: [(value: String, label: String)] = [
        ("option+space", "⌥ Space"),
        ("control+space", "⌃ Space"),
        ("option+command+space", "⌥⌘ Space"),
        ("command+shift+space", "⇧⌘ Space"),
        ("control+option+space", "⌃⌥ Space"),
        ("f5", "F5"),
        ("f6", "F6"),
        ("f7", "F7"),
    ]

    /// 解析 "option+space" → (虚拟键码, 修饰键)
    static func parse(_ combo: String) -> (UInt32?, UInt32) {
        var mods: UInt32 = 0
        var key: UInt32? = nil
        for part in combo.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch part {
            case "option", "alt": mods |= UInt32(optionKey)
            case "control", "ctrl": mods |= UInt32(controlKey)
            case "command", "cmd": mods |= UInt32(cmdKey)
            case "shift": mods |= UInt32(shiftKey)
            case "space": key = UInt32(kVK_Space)
            case "f5": key = UInt32(kVK_F5)
            case "f6": key = UInt32(kVK_F6)
            case "f7": key = UInt32(kVK_F7)
            case "f8": key = UInt32(kVK_F8)
            default: break
            }
        }
        return (key, mods)
    }
}
