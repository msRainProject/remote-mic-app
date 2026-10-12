import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import RemoteMic

@Suite("Native key sequences")
struct KeyboardKeySequenceTests {
    private let keys = [
        CustomKeyboardShortcut(keyCode: 18, modifierFlags: [], keyLabel: "1"),
        CustomKeyboardShortcut(keyCode: 19, modifierFlags: [], keyLabel: "2"),
        CustomKeyboardShortcut(keyCode: 20, modifierFlags: [], keyLabel: "3"),
        CustomKeyboardShortcut(keyCode: 21, modifierFlags: [], keyLabel: "4"),
        CustomKeyboardShortcut(keyCode: 36, modifierFlags: [], keyLabel: "Return")
    ]

    @Test func orderedPairsAndLogsDoNotExposeKeys() {
        var edges: [ShortcutLifecycleTests.Edge] = []
        var logs: [String] = []
        #expect(KeyboardKeySequence.send(keys, accessibilityTrusted: { true }, hardwareFlags: { [] },
            eventPoster: {
                if $0.getIntegerValueField(.eventSourceUserData) != KeyboardInjector.syntheticEventMarker {
                    Issue.record("Missing synthetic marker")
                }
                edges.append(.init($0)); return true
            }, frontmostProcess: { 10 }, logger: { logs.append($0) }))
        #expect(edges.map(\.code) == [18, 18, 19, 19, 20, 20, 21, 21, 36, 36])
        #expect(edges.map(\.type) == Array(repeating: [CGEventType.keyDown, .keyUp], count: 5).flatMap { $0 })
        #expect(edges.allSatisfy { $0.flags.isEmpty })
        #expect(logs.count == 2)
        #expect(logs.last?.contains("result=submitted") == true)
        #expect(logs.last?.contains("submitted_steps=5") == true)
        #expect(logs.allSatisfy { !$0.contains("key_code") && !$0.contains("Return") && !$0.contains("key_label") })
        #expect(!ButtonAction.keySequence.allowsRepeat)
        #expect(ButtonAction.keySequence.category == .custom)
    }

    @Test func invalidConfigurationsEmitNothing() {
        let invalid: [[CustomKeyboardShortcut]?] = [nil, [],
            Array(repeating: keys[0], count: 33),
            [.init(keyCode: 128, modifierFlags: [], keyLabel: "Invalid")],
            [.init(keyCode: 55, modifierFlags: [], keyLabel: "Command")],
            [.init(keyCode: 18, modifierFlags: [], keyLabel: String(repeating: "x", count: 65))]]
        for payload in invalid {
            var count = 0
            #expect(!KeyboardKeySequence.send(payload, accessibilityTrusted: { true }, hardwareFlags: { [] },
                eventPoster: { _ in count += 1; return true }, frontmostProcess: { 10 }, logger: { _ in }))
            #expect(count == 0)
        }
    }

    @Test(arguments: ["permission_denied", "target_changed", "physical_modifier_held", "deadline_exceeded"])
    func cancellationAfterFirstStepNeverSendsReturn(_ reason: String) {
        var edges: [ShortcutLifecycleTests.Edge] = []
        var logs: [String] = []
        #expect(!KeyboardKeySequence.send(keys,
            accessibilityTrusted: { reason != "permission_denied" || edges.isEmpty },
            hardwareFlags: { reason == "physical_modifier_held" && !edges.isEmpty ? .maskCommand : [] },
            eventPoster: { edges.append(.init($0)); return true },
            frontmostProcess: { reason == "target_changed" && !edges.isEmpty ? 11 : 10 },
            now: { reason == "deadline_exceeded" && !edges.isEmpty ? 3 : 0 },
            logger: { logs.append($0) }))
        #expect(edges.map(\.code) == [18, 18])
        #expect(logs.count == 2)
        #expect(logs.last?.contains("reason=\(reason)") == true)
        #expect(logs.last?.contains("submitted_steps=1") == true)
    }

    @Test func deniedOrUnknownTargetDoesNotSubmit() {
        for denied in [false, true] {
            var attempts = 0
            #expect(!KeyboardKeySequence.send(keys, accessibilityTrusted: { !denied }, hardwareFlags: { [] },
                eventPoster: { _ in attempts += 1; return true }, frontmostProcess: { denied ? 10 : nil }, logger: { _ in }))
            #expect(attempts == 0)
        }
    }

    @Test func failedDownReleasesKeyAndNextTriggerRecovers() {
        var edges: [ShortcutLifecycleTests.Edge] = []
        #expect(!KeyboardKeySequence.send(keys, accessibilityTrusted: { true }, hardwareFlags: { [] },
            eventPoster: { edges.append(.init($0)); return edges.count != 3 }, frontmostProcess: { 10 }, logger: { _ in }))
        #expect(edges.map(\.code) == [18, 18, 19, 19])
        #expect(edges.last?.type == .keyUp)
        edges = []
        #expect(KeyboardKeySequence.send(keys, accessibilityTrusted: { true }, hardwareFlags: { [] },
            eventPoster: { edges.append(.init($0)); return true }, frontmostProcess: { 10 }, logger: { _ in }))
        #expect(edges.count == 10)
    }

    @Test func modifiersAreReleasedBeforeNextStepAndDuplicatesRemain() {
        let modified = CustomKeyboardShortcut(keyCode: 18, modifierFlags: .shift, keyLabel: "1")
        var edges: [ShortcutLifecycleTests.Edge] = []
        #expect(KeyboardKeySequence.send([modified, keys[0], keys[0]], accessibilityTrusted: { true },
            hardwareFlags: { [] }, eventPoster: { edges.append(.init($0)); return true },
            frontmostProcess: { 10 }, logger: { _ in }))
        #expect(edges.map(\.code) == [56, 18, 18, 56, 18, 18, 18, 18])
        #expect(edges[3].type == .flagsChanged)
        #expect(edges[3...].allSatisfy { $0.flags.isEmpty })
    }

    @Test(arguments: Array(0..<4))
    func failureInModifiedStepReleasesModifiersAndStops(_ failureIndex: Int) {
        let modified = CustomKeyboardShortcut(keyCode: 18, modifierFlags: .command, keyLabel: "1")
        var edges: [ShortcutLifecycleTests.Edge] = []
        #expect(!KeyboardKeySequence.send([modified, keys[4]], accessibilityTrusted: { true },
            hardwareFlags: { [] }, eventPoster: {
                edges.append(.init($0)); return edges.count - 1 != failureIndex
            }, frontmostProcess: { 10 }, logger: { _ in }))
        #expect(!edges.contains { $0.code == 36 })
        #expect(edges.last?.code == 55)
        #expect(edges.last?.type == .flagsChanged)
        #expect(edges.last?.flags.isEmpty == true)
    }

    @Test func reloadAndBackupPreserveSequenceAndUnrelatedBindings() throws {
        let name = "KeySequenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let sequence = ConfiguredButtonAction(action: .keySequence, shortcut: nil, keySequence: keys)
        let shortcut = ConfiguredButtonAction(action: .customShortcut,
            shortcut: .init(keyCode: 48, modifierFlags: .command, keyLabel: "Tab"))
        settings.setBaseBinding(sequence, for: .menu, trigger: .doubleClick, profileID: nil)
        settings.setBaseBinding(shortcut, for: .tv, trigger: .doubleClick, profileID: nil)
        settings.setBaseBinding(.disabled, for: .menu, trigger: .longPress, profileID: nil)
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.configuredBaseAction(for: .menu, trigger: .doubleClick) == sequence)
        let targetName = "KeySequenceImportTests.\(UUID().uuidString)"
        let targetDefaults = try #require(UserDefaults(suiteName: targetName))
        defer { targetDefaults.removePersistentDomain(forName: targetName) }
        let target = AppSettings(defaults: targetDefaults)
        try target.importConfiguration(from: settings.exportedConfigurationData())
        #expect(target.configuredBaseAction(for: .menu, trigger: .doubleClick) == sequence)
        #expect(target.configuredBaseAction(for: .tv, trigger: .doubleClick) == shortcut)
        #expect(target.configuredBaseAction(for: .menu, trigger: .longPress) == .disabled)
        let legacy = try JSONDecoder().decode(ConfiguredButtonAction.self,
            from: Data(#"{"action":"customShortcut","shortcut":{"keyCode":18,"modifierFlagsRawValue":0,"keyLabel":"1"}}"#.utf8))
        #expect(legacy.keySequence == nil)
        #expect(legacy.shortcut?.keyCode == 18)
    }

    @Test func invalidImportedSequenceShadowsOldMapping() throws {
        for payload: [CustomKeyboardShortcut]? in [nil, [], Array(repeating: keys[0], count: 33)] {
            let name = "KeySequenceInvalidImport.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let source = AppSettings(defaults: defaults)
            source.setAction(.returnKey, for: .menu, trigger: .doubleClick)
            source.setBaseBinding(.init(action: .keySequence, shortcut: nil, keySequence: payload),
                for: .menu, trigger: .doubleClick, profileID: nil)
            try source.importConfiguration(from: source.exportedConfigurationData())
            #expect(source.configuredBaseAction(for: .menu, trigger: .doubleClick) == .disabled)
        }
    }
}
