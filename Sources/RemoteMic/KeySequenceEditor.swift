import SwiftUI

struct KeySequenceEditor: View {
    let keys: [CustomKeyboardShortcut]
    let onChange: ([CustomKeyboardShortcut]) -> Void
    @EnvironmentObject private var localization: LocalizationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localization.text("action.key_sequence"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(keys.count) / \(KeyboardKeySequence.maximumStepCount)")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                Button(localization.text("key_sequence.clear")) { onChange([]) }
                    .disabled(keys.isEmpty)
            }
            Text(localization.text("key_sequence.help"))
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if keys.isEmpty {
                Text(localization.text("key_sequence.empty"))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            ForEach(keys.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 28)
                    Text(keys[index].visualDisplayName(using: localization))
                        .font(.system(size: 15, weight: .semibold))
                        .help(keys[index].detailedDisplayName(using: localization))
                        .accessibilityLabel(keys[index].detailedDisplayName(using: localization))
                    Spacer()
                    Button { move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0)
                        .accessibilityLabel(localization.text("key_sequence.move_up"))
                    Button { move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == keys.count - 1)
                        .accessibilityLabel(localization.text("key_sequence.move_down"))
                    Button {
                        var updated = keys
                        updated.remove(at: index)
                        onChange(updated)
                    } label: { Image(systemName: "minus.circle") }
                    .accessibilityLabel(localization.text("key_sequence.remove"))
                }
                .font(.system(size: 13))
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
            KeyboardShortcutPicker(
                shortcut: nil, showsStandardKeyboardInitially: true,
                allowsStandaloneModifiers: false
            ) { key in
                guard keys.count < KeyboardKeySequence.maximumStepCount else { return }
                onChange(keys + [key])
            }
            .disabled(keys.count >= KeyboardKeySequence.maximumStepCount)
        }
        .padding(16)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard keys.indices.contains(index), keys.indices.contains(destination) else { return }
        var updated = keys
        updated.swapAt(index, destination)
        onChange(updated)
    }
}
