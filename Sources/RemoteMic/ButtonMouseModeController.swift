import Foundation

/// One transient mouse session per Xiaomi HID monitor; never changes stored mappings.
final class ButtonMouseModeController {
    static let scrollButtons: Set<RemoteButton> = [.volumeUp, .volumeDown]
    static let controlledButtons = Set<RemoteButton>([.up, .down, .left, .right, .ok]).union(scrollButtons)
    static let frameMilliseconds: UInt64 = 16
    static let scrollRepeatDelayMilliseconds: UInt64 = 350
    static let scrollRepeatMilliseconds: UInt64 = 100
    static let scrollPixels = 40.0

    private let scheduler: HIDRemoteScheduling
    private let permissions: () -> Bool
    private let output: (AppleSiriRemoteTouchOutput) -> Bool
    private let logger: (String) -> Void
    private var movementTask: HIDRemoteScheduledTask?
    private var heldDirections: Set<RemoteButton> = []
    private var scrollTask: HIDRemoteScheduledTask?
    private var heldScrollButtons: Set<RemoteButton> = []
    private var scrollGeneration: UInt64 = 0
    private var scrollActive = false
    private var generation: UInt64 = 0
    private var movementActive = false
    // Shared process-local sequence: simultaneous devices must not reuse log operation IDs.
    private final class OperationSequence: @unchecked Sendable {
        private let lock = NSLock()
        private var value: UInt64 = 0
        func take() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            value += 1
            return value
        }
    }
    private static let operations = OperationSequence()
    private var modeOperationID: UInt64 = 0
    private var movementOperationID: UInt64 = 0
    private var clickOperationID: UInt64 = 0
    private var scrollOperationID: UInt64 = 0
    private var scrollStartedAt = 0.0
    private var submittedScrollFrames = 0
    private var movementStartedAt = 0.0
    private var movementFrames = 0
    private var submittedFrames = 0
    private(set) var isEnabled = false
    var onModeChanged: ((Bool) -> Void)?

    init(scheduler: HIDRemoteScheduling, permissions: @escaping () -> Bool,
         output: @escaping (AppleSiriRemoteTouchOutput) -> Bool,
         logger: @escaping (String) -> Void) {
        self.scheduler = scheduler
        self.permissions = permissions
        self.output = output
        self.logger = logger
    }

    deinit { movementTask?.cancel(); scrollTask?.cancel() }

    func toggle() {
        if isEnabled {
            cancel(reason: "user_toggle")
        } else {
            generation += 1
            modeOperationID = Self.operations.take()
            log("MODE", phase: "requested", result: "pending", reason: "user_toggle")
            guard permissions() else {
                log("MODE", phase: "failed", result: "failed", reason: "permission_denied")
                return
            }
            isEnabled = true
            log("MODE", phase: "started", result: "enabled", reason: "user_toggle")
            onModeChanged?(true)
        }
    }

    func press(_ button: RemoteButton) {
        guard isEnabled, Self.controlledButtons.contains(button) else { return }
        guard permissions() else { cancel(reason: "permission_revoked"); return }
        if Self.scrollButtons.contains(button) {
            pressScroll(button)
            return
        }
        if button == .ok {
            clickOperationID = Self.operations.take()
            let submitted = output(.click)
            log("CLICK", phase: "completed",
                result: submitted ? "submitted" : "failed", reason: submitted ? "input_posted" : "output_rejected",
                fields: "target_result=unknown")
            if !submitted { cancel(reason: "output_rejected") }
            return
        }
        guard heldDirections.insert(button).inserted else { return }
        if movementTask == nil {
            generation += 1
            movementOperationID = Self.operations.take()
            movementActive = true
            movementStartedAt = ProcessInfo.processInfo.systemUptime
            movementFrames = 0
            submittedFrames = 0
            log("MOVE", phase: "started", result: "accepted", reason: "direction_pressed")
            // The first down edge moves immediately, without a repeat/gesture window.
            step()
            guard isEnabled, !heldDirections.isEmpty else { return }
            let expectedGeneration = generation
            movementTask = scheduler.schedule(afterMilliseconds: Self.frameMilliseconds,
                repeatingEveryMilliseconds: Self.frameMilliseconds) { [weak self] in
                guard let self, self.isEnabled, self.generation == expectedGeneration else { return }
                self.step()
            }
        } else {
            step()
        }
    }

    func release(_ button: RemoteButton) {
        if Self.scrollButtons.contains(button) {
            guard heldScrollButtons.remove(button) != nil else { return }
            if heldScrollButtons.isEmpty { stopScroll(reason: "released") }
            else { scrollStep() }
            return
        }
        heldDirections.remove(button)
        if heldDirections.isEmpty { stopMovement(reason: "released") }
    }

    func cancel(reason: String) {
        stopMovement(reason: reason)
        stopScroll(reason: reason)
        heldDirections.removeAll()
        heldScrollButtons.removeAll()
        guard isEnabled else { return }
        isEnabled = false
        generation += 1
        log("MODE", phase: "completed", result: "disabled", reason: reason)
        onModeChanged?(false)
    }

    private func step() {
        guard isEnabled, !heldDirections.isEmpty else { return }
        guard permissions() else { cancel(reason: "permission_revoked"); return }
        let x = (heldDirections.contains(.right) ? 1.0 : 0.0) - (heldDirections.contains(.left) ? 1.0 : 0.0)
        let y = (heldDirections.contains(.down) ? 1.0 : 0.0) - (heldDirections.contains(.up) ? 1.0 : 0.0)
        guard x != 0 || y != 0 else { return }
        // Fixed per-frame bounds avoid large jumps if the main queue is delayed.
        // Ramp from precise taps (3 points) to 12 points/frame over about 0.5 s.
        let distance = min(12.0, 3.0 + Double(movementFrames) * 0.3)
        let length = (x * x + y * y).squareRoot()
        guard output(.move(deltaX: x / length * distance, deltaY: y / length * distance)) else {
            cancel(reason: "output_rejected")
            return
        }
        if submittedFrames == 0 {
            log("MOVE", phase: "submitted", result: "submitted", reason: "first_input_posted",
                fields: "first_output_ms=\(Int((ProcessInfo.processInfo.systemUptime - movementStartedAt) * 1000)) target_result=unknown")
        }
        movementFrames += 1
        submittedFrames += 1
    }

    private func stopMovement(reason: String) {
        guard movementActive else { return }
        movementTask?.cancel()
        movementTask = nil
        movementActive = false
        generation += 1
        log("MOVE", phase: "completed", result: reason == "output_rejected" ? "failed" : "stopped", reason: reason,
            fields: "submitted_frames=\(submittedFrames) elapsed_ms=\(Int((ProcessInfo.processInfo.systemUptime - movementStartedAt) * 1000)) target_result=unknown")
        submittedFrames = 0
        movementFrames = 0
    }

    private func pressScroll(_ button: RemoteButton) {
        guard heldScrollButtons.insert(button).inserted else { return }
        if scrollTask == nil {
            scrollGeneration += 1
            scrollOperationID = Self.operations.take()
            scrollActive = true
            scrollStartedAt = ProcessInfo.processInfo.systemUptime
            submittedScrollFrames = 0
            log("SCROLL", phase: "started", result: "accepted", reason: "scroll_pressed",
                fields: "repeat_delay_ms=\(Self.scrollRepeatDelayMilliseconds) repeat_interval_ms=\(Self.scrollRepeatMilliseconds)")
            scrollStep()
            guard isEnabled, !heldScrollButtons.isEmpty else { return }
            // Independent generation lets pointer movement and scrolling coexist.
            let expectedGeneration = scrollGeneration
            scrollTask = scheduler.schedule(afterMilliseconds: Self.scrollRepeatDelayMilliseconds,
                repeatingEveryMilliseconds: Self.scrollRepeatMilliseconds) { [weak self] in
                guard let self, self.isEnabled, self.scrollGeneration == expectedGeneration else { return }
                self.scrollStep()
            }
        } else {
            scrollStep()
        }
    }

    private func scrollStep() {
        guard isEnabled, !heldScrollButtons.isEmpty else { return }
        guard permissions() else { cancel(reason: "permission_revoked"); return }
        let direction = (heldScrollButtons.contains(.volumeUp) ? 1.0 : 0.0) -
            (heldScrollButtons.contains(.volumeDown) ? 1.0 : 0.0)
        guard direction != 0 else { return }
        guard output(.scroll(pixels: direction * Self.scrollPixels)) else {
            cancel(reason: "output_rejected")
            return
        }
        if submittedScrollFrames == 0 {
            log("SCROLL", phase: "submitted", result: "submitted", reason: "first_input_posted",
                fields: "first_output_ms=\(Int((ProcessInfo.processInfo.systemUptime - scrollStartedAt) * 1000)) target_result=unknown")
        }
        submittedScrollFrames += 1
    }

    private func stopScroll(reason: String) {
        guard scrollActive else { return }
        scrollTask?.cancel()
        scrollTask = nil
        scrollActive = false
        scrollGeneration += 1
        log("SCROLL", phase: "completed", result: reason == "output_rejected" ? "failed" : "stopped", reason: reason,
            fields: "submitted_frames=\(submittedScrollFrames) elapsed_ms=\(Int((ProcessInfo.processInfo.systemUptime - scrollStartedAt) * 1000)) target_result=unknown")
        submittedScrollFrames = 0
    }

    private func log(_ action: String, phase: String, result: String, reason: String, fields: String = "") {
        let operationID: UInt64
        switch action {
        case "MODE": operationID = modeOperationID
        case "MOVE": operationID = movementOperationID
        case "SCROLL": operationID = scrollOperationID
        default: operationID = clickOperationID
        }
        logger("MOUSE \(action) operation_id=mouse_\(operationID) phase=\(phase) result=\(result) reason=\(reason)" +
            (fields.isEmpty ? "" : " \(fields)"))
    }
}
