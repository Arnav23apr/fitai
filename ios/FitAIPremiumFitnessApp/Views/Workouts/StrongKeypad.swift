import SwiftUI

/// Strong-style overlay numeric keypad. Replaces iOS's default numpad with a
/// fitness-tuned one: 0-9, decimal, backspace, ±5 quick-adjust plate keys,
/// and Next-field navigation. Slides up from the bottom while a weight or
/// reps cell is focused.
///
/// The user's text/Double bindings are owned by the row; this view just
/// emits keystroke intents and lets the row decide how to mutate them.
struct StrongKeypad: View {
    enum Key: Equatable {
        case digit(String)
        case dot
        case backspace
        case adjust(Double)   // +5, -5 etc.
        case next
        case dismiss
    }

    /// Whether the active field accepts a decimal (weight, RPE) vs integer
    /// only (reps). Hides the dot key when false.
    let allowsDecimal: Bool
    let onKey: (Key) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.4)
            keypadGrid
                .padding(.horizontal, 6)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            // Top accent strip — gives the panel weight against the
            // dark workout content behind it.
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(height: 1)
        }
    }

    private var keypadGrid: some View {
        HStack(spacing: 6) {
            digitsColumn
            sideColumn
        }
    }

    private var digitsColumn: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                keyButton("1") { onKey(.digit("1")) }
                keyButton("2") { onKey(.digit("2")) }
                keyButton("3") { onKey(.digit("3")) }
            }
            HStack(spacing: 6) {
                keyButton("4") { onKey(.digit("4")) }
                keyButton("5") { onKey(.digit("5")) }
                keyButton("6") { onKey(.digit("6")) }
            }
            HStack(spacing: 6) {
                keyButton("7") { onKey(.digit("7")) }
                keyButton("8") { onKey(.digit("8")) }
                keyButton("9") { onKey(.digit("9")) }
            }
            HStack(spacing: 6) {
                if allowsDecimal {
                    keyButton(".") { onKey(.dot) }
                } else {
                    invisibleKey()
                }
                keyButton("0") { onKey(.digit("0")) }
                keyButton(systemImage: "delete.left", weight: .medium) { onKey(.backspace) }
            }
        }
    }

    private var sideColumn: some View {
        VStack(spacing: 6) {
            keyButton(systemImage: "keyboard.chevron.compact.down", weight: .medium) {
                onKey(.dismiss)
            }
            adjustPair
            keyButton(label: "Next", tint: .blue, foreground: .white) {
                onKey(.next)
            }
        }
        .frame(width: 90)
    }

    private var adjustPair: some View {
        HStack(spacing: 6) {
            keyButton(label: "−5", weight: .heavy) {
                onKey(.adjust(-5))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            keyButton(label: "+5", weight: .heavy) {
                onKey(.adjust(5))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    // MARK: - Key style helpers

    private func keyButton(_ digit: String, action: @escaping () -> Void) -> some View {
        keyButton(label: digit, weight: .semibold, action: action)
    }

    private func keyButton(systemImage: String, weight: Font.Weight, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: weight))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.primary.opacity(0.10))
                .clipShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func keyButton(
        label: String,
        weight: Font.Weight = .semibold,
        tint: Color = Color.primary.opacity(0.10),
        foreground: Color = Color.primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: weight, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(tint)
                .clipShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func invisibleKey() -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 42)
    }
}
