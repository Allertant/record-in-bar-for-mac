import AppKit
import SwiftData
import SwiftUI

extension EditorPageView {
    @MainActor
    func shareText() {
        var text = ""
        if !draftTitle.isEmpty {
            text += draftTitle
        }
        if !draftNote.isEmpty {
            if !text.isEmpty { text += "\n\n" }
            text += draftNote
        }
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showShareSheet = false
        }
        showShareSuccessToast(message: "文字复制成功")
    }

    @MainActor
    func generateAndShareImage() {
        guard !draftTitle.isEmpty || !draftNote.isEmpty else { return }
        isGeneratingImage = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let timeString = dateFormatter.string(from: Date())

        let includeSummary = appSettings.first?.includeAISummaryInShareImage ?? true
        let summaryText: String? = {
            guard includeSummary, let topic else { return nil }
            return latestSummary(for: topic)?.summaryText
        }()

        let segments = parseNoteSegments(draftNote)
        let card = ShareableNoteCard(
            title: draftTitle,
            noteSegments: segments,
            time: timeString,
            summary: summaryText,
            colorScheme: colorScheme
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))

            guard let nsImage = renderer.nsImage else {
                isGeneratingImage = false
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(nsImage.tiffRepresentation!, forType: .tiff)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showShareSheet = false
                previewImage = nsImage
                showImagePreview = true
                isGeneratingImage = false
            }
        }
    }

    @MainActor
    func closeShareImagePreview() {
        showImagePreview = false
        previewImage = nil
        showShareSuccessToast(message: "图片复制成功")
    }

    @MainActor
    func showShareSuccessToast(message: String) {
        shareSuccessMessage = message
        withAnimation(.easeOut(duration: 0.18)) {
            showShareSuccess = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeIn(duration: 0.28)) {
                showShareSuccess = false
            }
        }
    }

    func parseNoteSegments(_ text: String) -> [ShareableNoteSegment] {
        let pattern = #"\[IMG:([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text.isEmpty ? [] : [.text(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        var segments: [ShareableNoteSegment] = []
        var lastEnd = 0

        for match in matches {
            let fullRange = match.range
            if fullRange.location > lastEnd {
                let between = nsText.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
                if !between.isEmpty {
                    segments.append(.text(between))
                }
            }

            let uuidRange = match.range(at: 1)
            let uuidString = nsText.substring(with: uuidRange)
            if let uuid = UUID(uuidString: uuidString) {
                let descriptor = FetchDescriptor<NoteImage>(predicate: #Predicate<NoteImage> { $0.id == uuid })
                if let ni = try? modelContext.fetch(descriptor).first,
                   let image = ImageStorage.loadImage(relativePath: ni.relativePath) {
                    segments.append(.image(image))
                }
            }

            lastEnd = fullRange.location + fullRange.length
        }

        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            if !remaining.isEmpty {
                segments.append(.text(remaining))
            }
        }

        return segments
    }
}
