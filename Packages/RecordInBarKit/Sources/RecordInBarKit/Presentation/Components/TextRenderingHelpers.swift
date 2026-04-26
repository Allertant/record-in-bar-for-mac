import SwiftUI

struct HighlightedText: View {
    let text: String
    let query: String
    let font: Font
    let foregroundStyle: Color
    let highlightStyle: Color

    init(
        _ text: String,
        query: String,
        font: Font = .system(size: 12),
        foregroundStyle: Color = .primary,
        highlightStyle: Color = .red
    ) {
        self.text = text
        self.query = query
        self.font = font
        self.foregroundStyle = foregroundStyle
        self.highlightStyle = highlightStyle
    }

    var body: some View {
        Text(highlightedAttributedString)
            .font(font)
    }

    private var highlightedAttributedString: AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = foregroundStyle

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return attributed }

        let lowercasedText = text.lowercased()
        let lowercasedQuery = trimmedQuery.lowercased()
        var startIndex = lowercasedText.startIndex

        while let range = lowercasedText.range(of: lowercasedQuery, range: startIndex..<lowercasedText.endIndex) {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].foregroundColor = highlightStyle
                attributed[attributedRange].font = .system(size: 12, weight: .semibold)
            }
            startIndex = range.upperBound
        }

        return attributed
    }
}

enum RelativeTimeFormatter {
    static func string(for date: Date, reference: Date) -> String {
        let delta = max(0, Int(reference.timeIntervalSince(date)))
        return switch delta {
        case 0..<3:
            "现在"
        case 3..<60:
            "\(delta) 秒前"
        case 60..<3600:
            "\(delta / 60) 分钟前"
        case 3600..<86_400:
            "\(delta / 3600) 小时前"
        default:
            "\(delta / 86_400) 天前"
        }
    }
}

enum HistoryTimeFormatter {
    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M月d日"
        return df
    }()

    static func string(for date: Date) -> String {
        formatter.string(from: date)
    }
}
