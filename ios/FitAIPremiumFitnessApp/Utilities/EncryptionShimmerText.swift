import SwiftUI

/// Text that briefly renders as scrambled glyphs and "decrypts" into
/// the real string. The hero FX on the Trust screen — pairs with the
/// "your data stays yours" promise by making every privacy bullet read
/// like it's being decoded in front of you.
///
/// Pure SwiftUI: TimelineView ticks at 30fps, the visible characters
/// are computed deterministically from elapsed time so the shimmer is
/// stable across frames (no flicker) but still feels alive.
///
/// Flip `trigger` from false → true to play the animation. Spaces and
/// punctuation pass through unchanged so the layout shape stays
/// readable while the letters cycle.
struct EncryptionShimmerText: View {
    let text: String
    /// Total reveal duration. Letters land sequentially over the
    /// first 60% of this; the remainder is a settle pad so the final
    /// line never reveals on a per-frame edge.
    var duration: Double = 0.7
    var trigger: Bool

    @State private var animationStart: Date? = nil

    /// Pool of substitute glyphs. Mixed alphanumerics + a few symbols
    /// for a cyber/decryption feel. No exotic unicode — keeps the
    /// system font monospace-ish so width doesn't jitter.
    private static let pool: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%@&*")

    var body: some View {
        Group {
            if let start = animationStart {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                    Text(scrambled(elapsed: ctx.date.timeIntervalSince(start)))
                }
            } else {
                Text(text)
            }
        }
        .onChange(of: trigger) { _, newValue in
            guard newValue else {
                animationStart = nil
                return
            }
            animationStart = Date()
            // Drop back to the static Text path once the reveal is
            // settled. Keeps the TimelineView from churning forever.
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.10) {
                animationStart = nil
            }
        }
    }

    /// Compute the displayed string for a given elapsed time. Each
    /// non-whitespace character has a stable "reveal time" derived
    /// from its index; before that time it shows a deterministically
    /// shuffling pool glyph, after it shows the real character.
    private func scrambled(elapsed: TimeInterval) -> String {
        let chars = Array(text)
        // Sequentially reveal over the first 60% of duration so the
        // last 40% is a settle phase (everything readable, slight
        // chromatic shimmer fading out).
        let revealWindow = duration * 0.60
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        for (i, c) in chars.enumerated() {
            if c.isWhitespace || c.isPunctuation {
                out.append(c)
                continue
            }
            let revealTime = (Double(i) / Double(max(chars.count, 1))) * revealWindow
            if elapsed >= revealTime {
                out.append(c)
            } else {
                // Deterministic shuffle: index derived from elapsed +
                // position so the glyph changes ~12 times per second
                // without using Double.random (which would flicker
                // because each frame would produce different results).
                let shuffleIdx = Int((elapsed + 1.0) * 12) &+ (i &* 7)
                let idx = ((shuffleIdx % Self.pool.count) + Self.pool.count) % Self.pool.count
                out.append(Self.pool[idx])
            }
        }
        return String(out)
    }
}
