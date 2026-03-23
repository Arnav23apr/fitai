import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(parsedLines(text).enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: MDLine) -> some View {
        switch line.kind {
        case .h1:
            Text(line.inline)
                .font(.headline.weight(.bold))
                .padding(.top, 6)
        case .h2:
            Text(line.inline)
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)
        case .divider:
            Divider().opacity(0.25).padding(.vertical, 4)
        case .bullet(let depth):
            HStack(alignment: .top, spacing: 5) {
                Text("•")
                    .font(.subheadline)
                    .foregroundStyle(depth > 0 ? Color.secondary : Color.primary)
                    .padding(.leading, CGFloat(depth) * 12)
                Text(line.inline).font(.subheadline)
            }
        case .empty:
            Color.clear.frame(height: 2)
        case .text:
            Text(line.inline).font(.subheadline)
        }
    }
}

// MARK: - Line Model

private enum MDKind { case h1, h2, divider, bullet(Int), empty, text }

private struct MDLine {
    let kind: MDKind
    let inline: AttributedString

    init(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            kind = .empty; inline = AttributedString(); return
        }
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            kind = .divider; inline = AttributedString(); return
        }
        if trimmed.hasPrefix("# ") {
            kind = .h1
            inline = MDLine.parseInline(String(trimmed.dropFirst(2)))
            return
        }
        if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
            let drop = trimmed.hasPrefix("### ") ? 4 : 3
            kind = .h2
            inline = MDLine.parseInline(String(trimmed.dropFirst(drop)))
            return
        }
        let indentDepth = raw.prefix(while: { $0 == " " }).count / 2
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            kind = .bullet(indentDepth)
            inline = MDLine.parseInline(String(trimmed.dropFirst(2)))
            return
        }
        kind = .text
        inline = MDLine.parseInline(trimmed)
    }

    static func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var i = text.startIndex

        while i < text.endIndex {
            if text[i] == "*" {
                let next = text.index(after: i)
                let isDouble = next < text.endIndex && text[next] == "*"
                let delim = isDouble ? "**" : "*"
                let contentStart = isDouble ? (text.index(i, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex) : next

                if contentStart < text.endIndex,
                   let closeRange = text.range(of: delim, range: contentStart..<text.endIndex) {
                    let content = String(text[contentStart..<closeRange.lowerBound])
                    if !content.isEmpty && !content.hasPrefix(" ") {
                        var attr = AttributedString(content)
                        attr.font = .subheadline.weight(.semibold)
                        result.append(attr)
                        i = closeRange.upperBound
                        continue
                    }
                }
            }
            var plain = AttributedString(String(text[i]))
            plain.font = .subheadline
            result.append(plain)
            i = text.index(after: i)
        }
        return result
    }
}

// MARK: - Parser

private func parsedLines(_ text: String) -> [MDLine] {
    text.components(separatedBy: "\n").map(MDLine.init)
}
