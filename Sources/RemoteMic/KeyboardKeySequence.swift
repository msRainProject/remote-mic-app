import AppKit
import CoreGraphics
import Foundation

/// A bounded native keyboard transaction. It never reads text or uses the clipboard.
enum KeyboardKeySequence {
    static let maximumStepCount = 32
    private static let physicalModifiers: CGEventFlags = [
        .maskControl, .maskAlternate, .maskShift, .maskCommand, .maskSecondaryFn
    ]

    static func validated(_ keys: [CustomKeyboardShortcut]) -> [CustomKeyboardShortcut]? {
        guard !keys.isEmpty, keys.count <= maximumStepCount else { return nil }
        var result: [CustomKeyboardShortcut] = []
        for key in keys {
            // Modifier-only steps could leave a later step with ambiguous ownership.
            guard key.keyCode <= 127, !key.keyLabel.isEmpty, key.keyLabel.count <= 64,
                  !StandaloneKeyboardModifier.allCases.contains(where: { $0.keyCode == key.keyCode })
            else { return nil }
            result.append(CustomKeyboardShortcut(
                keyCode: key.keyCode, modifierFlags: key.modifierFlags, keyLabel: key.keyLabel
            ))
        }
        return result
    }

    @discardableResult
    static func send(
        _ keys: [CustomKeyboardShortcut]?,
        accessibilityTrusted: () -> Bool,
        hardwareFlags: () -> CGEventFlags,
        eventPoster: (CGEvent) -> Bool,
        frontmostProcess: () -> pid_t? = { NSWorkspace.shared.frontmostApplication?.processIdentifier },
        now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        logger: (String) -> Void = { AppLogger.shared.write($0) }
    ) -> Bool {
        ShortcutEventSequence.withTransaction {
            let prefix = "KEY SEQUENCE operation_id=\(UUID().uuidString)"
            let started = now()
            var result = "failed"
            var reason = "invalid_configuration"
            var submittedSteps = 0
            logger("\(prefix) phase=requested step_count=\(keys?.count ?? 0)")
            defer {
                logger("\(prefix) phase=completed result=\(result) reason=\(reason) " +
                    "submitted_steps=\(submittedSteps) elapsed_ms=\(Int(max(0, now() - started) * 1_000)) " +
                    "user_visible_result=unknown")
            }
            guard let keys, let validated = validated(keys) else { return false }
            guard let target = frontmostProcess() else {
                reason = "target_unavailable"
                return false
            }
            for key in validated {
                guard accessibilityTrusted() else {
                    reason = "permission_denied"
                    return false
                }
                guard now() - started < 2 else {
                    result = "timed_out"
                    reason = "deadline_exceeded"
                    return false
                }
                guard frontmostProcess() == target else {
                    result = "cancelled"
                    reason = "target_changed"
                    return false
                }
                guard hardwareFlags().intersection(physicalModifiers).isEmpty else {
                    result = "cancelled"
                    reason = "physical_modifier_held"
                    return false
                }
                guard ShortcutEventSequence.send(
                    keyCode: CGKeyCode(key.keyCode), modifiers: key.cgEventFlags,
                    hardwareFlags: hardwareFlags, eventPoster: eventPoster, logger: { _ in }
                ) else {
                    reason = "event_submission_failed"
                    return false
                }
                submittedSteps += 1
            }
            result = "submitted"
            reason = "none"
            return true
        }
    }
}
