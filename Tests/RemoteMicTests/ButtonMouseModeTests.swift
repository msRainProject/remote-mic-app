import AppKit
import Foundation
import Testing
@testable import RemoteMic

@Suite("Xiaomi button mouse mode")
struct ButtonMouseModeTests {
    @Test func defaultsAndDisabledBindingKeepExistingMappings() throws {
        let h = try MouseModeHarness(bindToggle: false)
        h.report([.menu])
        h.scheduler.advance(by: 600)
        h.report([])
        h.report([.up])
        h.report([])
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.outputs.isEmpty)
        #expect(h.actions.contains(.contextMenu))
        #expect(h.actions.contains(.arrowUp))
        #expect(h.settings.action(for: .tv) == .appSwitcher)
    }

    @Test func menuLongPressTogglesOnceWithoutRunningShortPress() throws {
        let h = try MouseModeHarness()
        h.report([.menu])
        h.scheduler.advance(by: 549)
        #expect(!h.monitor.isMouseModeEnabled)
        h.scheduler.advance(by: 1)
        #expect(h.monitor.isMouseModeEnabled)
        #expect(h.monitor.status.key == "button_mapping.status.mouse_mode")
        h.report([.menu])
        h.scheduler.advance(by: 1_000)
        h.report([])
        #expect(h.monitor.isMouseModeEnabled)
        #expect(h.actions.isEmpty)
        h.toggle()
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.scheduler.pendingCount == 0)
        #expect(h.actions.isEmpty)
    }

    @Test func menuShortPressKeepsScreenshotShortcut() throws {
        let h = try MouseModeHarness()
        h.settings.setAction(.customShortcut, for: .menu)
        let screenshot = CustomKeyboardShortcut(keyCode: 20, modifierFlags: [.command, .shift], keyLabel: "3")
        h.settings.setShortcut(screenshot, for: .menu)
        h.report([.menu])
        h.scheduler.advance(by: 100)
        h.report([])
        #expect(h.actions == [.customShortcut])
        #expect(h.settings.configuredAction(for: .menu, trigger: .singleClick).shortcut == screenshot)
        h.toggle()
        h.toggle()
        #expect(h.actions == [.customShortcut])
        #expect(h.settings.configuredAction(for: .menu, trigger: .singleClick).shortcut == screenshot)
    }

    @Test func movementIsImmediateRampsAndStopsOnRelease() throws {
        let h = try MouseModeHarness()
        h.toggle()
        // Existing direction gestures must not delay or leak into mouse mode.
        h.settings.setAction(.commandCopy, for: .right, trigger: .doubleClick)
        h.settings.setAction(.commandPaste, for: .right, trigger: .longPress)
        h.report([.right])
        #expect(h.outputs == [.move(deltaX: 3, deltaY: 0)])
        h.report([.right])
        #expect(h.outputs.count == 1)
        h.scheduler.advance(by: 1_000)
        #expect(h.outputs.count > 50)
        #expect(h.outputs.last == .move(deltaX: 12, deltaY: 0))
        h.report([])
        let count = h.outputs.count
        h.scheduler.advance(by: 1_000)
        #expect(h.outputs.count == count)
        #expect(h.scheduler.pendingCount == 0)
        #expect(h.actions.isEmpty)
    }

    @Test func directionReplacementAndDiagonalSpeedAreBounded() throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.right])
        h.report([.left])
        #expect(h.outputs.last == .move(deltaX: -3, deltaY: 0))
        h.report([.left, .up])
        guard case let .move(x, y) = h.outputs.last else { Issue.record("Missing diagonal"); return }
        #expect(x < 0 && y < 0)
        #expect(abs((x * x + y * y).squareRoot() - 3.3) < 0.001)
        h.report([.left, .right, .up, .down])
        let count = h.outputs.count
        h.scheduler.advance(by: 100)
        #expect(h.outputs.count == count)
        h.report([])
        #expect(h.scheduler.pendingCount == 0)
    }

    @Test func okClicksOncePerEdgeAndAllowsRapidClicks() throws {
        let h = try MouseModeHarness()
        h.toggle()
        for _ in 0..<8 {
            h.report([.ok])
            h.report([.ok])
            h.scheduler.advance(by: 30)
            h.report([])
        }
        #expect(h.outputs == Array(repeating: .click, count: 8))
        #expect(h.actions.isEmpty)
        #expect(h.scheduler.pendingCount == 0)
    }

    @Test func togglingOffWhileHeldDoesNotLeakMappingsOrStaleCallbacks() throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.right])
        let stale = h.scheduler.lastRepeatingAction
        h.report([.right, .menu])
        h.scheduler.advance(by: 550)
        #expect(!h.monitor.isMouseModeEnabled)
        let count = h.outputs.count
        stale?()
        h.report([.right])
        h.scheduler.advance(by: 600)
        h.report([])
        #expect(h.outputs.count == count)
        #expect(h.actions.isEmpty)
        h.report([.up])
        h.report([])
        #expect(h.actions == [.arrowUp])
    }

    @Test func disconnectAndReconnectStartWithNormalMapping() throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.down])
        h.monitor.disconnectSimulatedDevice()
        let count = h.outputs.count
        h.scheduler.advance(by: 2_000)
        #expect(h.outputs.count == count)
        #expect(!h.monitor.isMouseModeEnabled)
        h.monitor.connectSimulatedDevice(fingerprint: "fixture", profileID: h.profileID)
        h.report([.up])
        h.report([])
        #expect(h.actions == [.arrowUp])
        h.toggle()
        h.report([.up])
        #expect(h.outputs.last == .move(deltaX: 0, deltaY: -3))
    }

    @Test(arguments: ["configuration", "runtime_action", "suspension", "stop"])
    func cancellationStopsMovementAndConsumesOldRelease(_ reason: String) throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.up])
        switch reason {
        case "configuration": h.monitor.cancelMappingInteractions()
        case "runtime_action": h.monitor.cancelPendingButtonActions()
        case "suspension": h.monitor.cancelMouseMode(reason: "application_suspended")
        default: h.monitor.stop()
        }
        let count = h.outputs.count
        h.scheduler.advance(by: 1_000)
        h.report([])
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.outputs.count == count)
        #expect(h.actions.isEmpty)
        h.report([.up])
        h.report([])
        #expect(h.actions == [.arrowUp])
    }

    @Test func revokedPermissionOrRejectedOutputStopsAndCanRecover() throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.up])
        h.permissionsGranted = false
        h.scheduler.advance(by: 16)
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.scheduler.pendingCount == 0)
        h.permissionsGranted = true
        h.report([])
        h.toggle()
        h.acceptOutput = false
        h.report([.ok])
        #expect(!h.monitor.isMouseModeEnabled)
        h.report([])
        h.acceptOutput = true
        h.toggle()
        h.report([.ok])
        #expect(h.outputs.last == .click)
    }

    @Test func appSwitcherKeepsNavigationAndReleasesCommand() throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.tv])
        h.report([])
        #expect(!h.monitor.isMouseModeEnabled)
        h.report([.right])
        h.report([])
        h.report([.ok])
        h.report([])
        #expect(h.outputs.isEmpty)
        #expect(h.keyStates.contains { $0.0 == 55 && $0.1 })
        #expect(h.keyStates.contains { $0.0 == 55 && !$0.1 })
    }

    @Test func multiDeviceDisconnectIsIsolated() throws {
        let a = try MouseModeHarness()
        let b = try MouseModeHarness()
        a.toggle(); b.toggle()
        a.report([.right]); b.report([.left])
        a.monitor.disconnectSimulatedDevice()
        b.scheduler.advance(by: 64)
        #expect(!a.monitor.isMouseModeEnabled)
        #expect(b.monitor.isMouseModeEnabled)
        #expect(b.outputs.count == 5)
        func operationIDs(_ logs: [String]) -> Set<Substring> {
            Set(logs.filter { $0.hasPrefix("MOUSE ") }.compactMap {
                $0.split(separator: " ").first { $0.hasPrefix("operation_id=") }
            })
        }
        #expect(operationIDs(a.logs).isDisjoint(with: operationIDs(b.logs)))
    }

    @Test func fallbackNativeArrowEventsAreSuppressedDuringMouseMode() throws {
        let h = try MouseModeHarness(isSeized: false)
        h.toggle()
        h.report([.right])
        let down = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 124, keyDown: true))
        let up = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 124, keyDown: false))
        #expect(h.suppressor.handle(type: .keyDown, event: down))
        h.report([])
        #expect(h.suppressor.handle(type: .keyUp, event: up))
        #expect(h.actions.isEmpty)
    }

    @Test func pendingDirectionalGesturesAreCancelledOnEntry() throws {
        let h = try MouseModeHarness()
        h.settings.setAction(.commandCopy, for: .up, trigger: .doubleClick)
        h.report([.up])
        // Start menu hold with the direction still down, then release it after entry.
        h.report([.up, .menu])
        h.scheduler.advance(by: 550)
        h.report([])
        h.scheduler.advance(by: 600)
        #expect(h.actions.isEmpty)
        #expect(h.outputs.isEmpty)
    }

    @Test func persistenceAndPickerRespectOptInAndHardwareBoundaries() throws {
        let h = try MouseModeHarness()
        let restored = AppSettings(defaults: h.defaults)
        #expect(restored.configuredAction(for: .menu, trigger: .longPress).action == .toggleMouseMode)
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(!ButtonAction.toggleMouseMode.allowsRepeat)
        #expect(!KeyboardInjector.send(.toggleMouseMode))
        #expect(!ButtonAction.pickerActions(installedBundleIdentifiers: [], current: .disabled,
            experimentalContinuousRecordingEnabled: false).contains(.toggleMouseMode))
        #expect(ButtonAction.pickerActions(installedBundleIdentifiers: [], current: .disabled,
            experimentalContinuousRecordingEnabled: false, supportsButtonMouseMode: true).contains(.toggleMouseMode))
    }

    @Test func disablingToggleAfterUseRestoresOriginalBehavior() throws {
        let h = try MouseModeHarness()
        h.toggle(); h.report([.up]); h.report([]); h.toggle()
        h.settings.setAction(.disabled, for: .menu, trigger: .longPress)
        h.monitor.cancelMappingInteractions()
        let count = h.outputs.count
        h.report([.menu]); h.scheduler.advance(by: 600); h.report([])
        h.report([.up]); h.report([])
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.outputs.count == count)
        #expect(h.actions == [.contextMenu, .arrowUp])
    }

    @Test func pointerButtonsCannotBecomeAnUnreachableExitBinding() throws {
        let h = try MouseModeHarness(bindToggle: false)
        h.settings.setAction(.toggleMouseMode, for: .ok)
        h.report([.ok]); h.report([])
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.outputs.isEmpty)
        #expect(h.logs.contains { $0.contains("reason=mouse_mode_reserved_button") })
    }

    @Test func failedFirstMovementHasOneTerminalAndNoTimer() throws {
        let h = try MouseModeHarness()
        h.toggle(); h.acceptOutput = false; h.report([.up])
        #expect(!h.monitor.isMouseModeEnabled)
        #expect(h.scheduler.pendingCount == 0)
        let terminals = h.logs.filter { $0.hasPrefix("MOUSE MOVE") && $0.contains("phase=completed") }
        #expect(terminals.count == 1)
        #expect(terminals.first?.contains("result=failed") == true)
        #expect(terminals.first?.contains("submitted_frames=0") == true)
    }

    @Test func menuDoubleClickKeepsItsBindingWhileLongPressToggles() throws {
        let h = try MouseModeHarness()
        h.settings.setAction(.commandCopy, for: .menu, trigger: .doubleClick)
        h.report([.menu]); h.report([])
        h.scheduler.advance(by: 100)
        h.report([.menu]); h.report([])
        #expect(h.actions == [.commandCopy])
        #expect(!h.monitor.isMouseModeEnabled)
        h.toggle()
        #expect(h.monitor.isMouseModeEnabled)
        #expect(h.actions == [.commandCopy])
    }

    @Test func movementLogsHaveOneCorrelatedTerminalAndNoIdentityOrCoordinates() throws {
        let h = try MouseModeHarness()
        h.toggle()
        h.report([.right])
        h.scheduler.advance(by: 160)
        h.report([])
        let movement = h.logs.filter { $0.hasPrefix("MOUSE MOVE") }
        #expect(movement.filter { $0.contains("phase=completed") }.count == 1)
        let ids = Set(movement.compactMap { $0.split(separator: " ").first { $0.hasPrefix("operation_id=") } })
        #expect(ids.count == 1)
        #expect(movement.last?.contains("submitted_frames=11") == true)
        #expect(movement.last?.contains("target_result=unknown") == true)
        #expect(!h.logs.joined().contains("fixture"))
        #expect(!h.logs.joined().contains(h.profileID.uuidString))
        #expect(!h.logs.joined().contains("deltaX"))
    }
}

private final class MouseModeHarness {
    let suiteName = "ButtonMouseModeTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let settings: AppSettings
    let profileID: UUID
    let scheduler = MouseModeScheduler()
    let suppressor = KeyboardEventSuppressor()
    var permissionsGranted = true
    var acceptOutput = true
    var outputs: [AppleSiriRemoteTouchOutput] = []
    var actions: [ButtonAction] = []
    var logs: [String] = []
    var keyStates: [(CGKeyCode, Bool)] = []
    var monitor: HIDRemoteMonitor!

    init(bindToggle: Bool = true, isSeized: Bool = true) throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        settings = AppSettings(defaults: defaults)
        settings.customMappingEnabled = true
        profileID = try #require(settings.selectedRemoteProfileID)
        if bindToggle { settings.setAction(.toggleMouseMode, for: .menu, trigger: .longPress) }
        monitor = HIDRemoteMonitor(settings: settings, profileID: profileID,
            eventSuppressor: suppressor, ownsEventSuppressor: false, scheduler: scheduler,
            runtimePermissions: { [weak self] in self?.permissionsGranted == true },
            actionPerformer: { [weak self] _, _, configured in self?.actions.append(configured.action); return true },
            frontmostBundleIdentifier: { "com.example.fixture" },
            diagnosticLogger: { [weak self] in self?.logs.append($0) },
            appSwitcherKeyStatePoster: { [weak self] code, pressed, _ in self?.keyStates.append((code, pressed)); return true },
            mouseOutput: { [weak self] output in
                guard let self, self.acceptOutput else { return false }
                self.outputs.append(output); return true
            })
        monitor.connectSimulatedDevice(fingerprint: "fixture", profileID: profileID, isSeized: isSeized)
    }

    deinit { monitor.stop(); defaults.removePersistentDomain(forName: suiteName) }

    func report(_ buttons: [RemoteButton]) {
        let bytes = buttons.flatMap { [UInt8(truncatingIfNeeded: $0.hidUsage), UInt8($0.hidUsage >> 8)] }
        monitor.handleSimulatedReport(reportID: 1, data: bytes.isEmpty ? Data(repeating: 0, count: 6) : Data(bytes))
    }

    func toggle() {
        report([.menu])
        scheduler.advance(by: 550)
        report([])
    }
}

private final class MouseModeScheduler: HIDRemoteScheduling {
    private final class Task: HIDRemoteScheduledTask {
        var deadline: UInt64
        let interval: UInt64?
        let action: () -> Void
        var cancelled = false
        init(deadline: UInt64, interval: UInt64?, action: @escaping () -> Void) {
            self.deadline = deadline; self.interval = interval; self.action = action
        }
        func cancel() { cancelled = true }
    }
    private var now: UInt64 = 0
    private var tasks: [Task] = []
    var pendingCount: Int { tasks.filter { !$0.cancelled }.count }
    var lastRepeatingAction: (() -> Void)? { tasks.last { $0.interval != nil }?.action }
    func schedule(afterMilliseconds: UInt64, repeatingEveryMilliseconds: UInt64?,
                  _ action: @escaping () -> Void) -> HIDRemoteScheduledTask {
        let task = Task(deadline: now + afterMilliseconds, interval: repeatingEveryMilliseconds, action: action)
        tasks.append(task); return task
    }
    func advance(by milliseconds: UInt64) {
        let target = now + milliseconds
        while let task = tasks.filter({ !$0.cancelled && $0.deadline <= target }).min(by: { $0.deadline < $1.deadline }) {
            now = task.deadline
            if let interval = task.interval { task.deadline += interval } else { task.cancelled = true }
            task.action()
        }
        now = target
    }
}
