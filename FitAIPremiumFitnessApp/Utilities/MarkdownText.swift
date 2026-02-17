import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        Text(parsedAttributedString)
    }

    private var parsedAttributedString: AttributedString {
        var result = AttributedString()
        let input = text

        var i = input.startIndex
        while i < input.endIndex {
            if input[i] == "*" {
                let boldResult = parseBold(from: i, in: input)
                if let (boldText, endIndex) = boldResult {
                    var attr = AttributedString(boldText)
                    attr.font = .subheadline.weight(.semibold)
                    result.append(attr)
                    i = endIndex
                    continue
                }
            }
            var plain = AttributedString(String(input[i]))
            plain.font = .subheadline
            result.append(plain)
            i = input.index(after: i)
        }

        return result
    }

    private func parseBold(from start: String.Index, in text: String) -> (String, String.Index)? {
        if text[start] == "*" {
            let afterStart: String.Index
            let delimiter: String
            if start < text.index(before: text.endIndex),
               text[text.index(after: start)] == "*" {
                afterStart = text.index(start, offsetBy: 2)
                delimiter = "**"
            } else {
                afterStart = text.index(after: start)
                delimiter = "*"
            }

            guard afterStart < text.endIndex else { return nil }

            if let closeRange = text.range(of: delimiter, range: afterStart..<text.endIndex) {
                let boldContent = String(text[afterStart..<closeRange.lowerBound])
                if !boldContent.isEmpty && !boldContent.hasPrefix(" ") && !boldContent.hasSuffix(" ") {
                    return (boldContent, closeRange.upperBound)
                }
            }
        }
        return nil
    }
}
