import AppKit
import SwiftUI

extension EditorPageView {
    @MainActor
    func openImagePreview(uuid: UUID) {
        guard let ni = noteImages.first(where: { $0.id == uuid }) else {
            return
        }

        imagePreviewTask?.cancel()
        let relativePath = ni.relativePath
        let targetScreen = imagePreviewScreen()
        let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow
        let existingPanel = imagePreviewPanel
        let previousPanelSize = existingPanel?.frame.size

        imagePreviewTask = Task.detached(priority: .userInitiated) {
            let image = ImageStorage.loadImage(relativePath: relativePath)
            guard !Task.isCancelled, let image else { return }

            await MainActor.run {
                currentPreviewImageID = uuid
                imagePreviewState.update(
                    image: image,
                    canGoPrevious: previousPreviewImageID(for: uuid) != nil,
                    canGoNext: nextPreviewImageID(for: uuid) != nil,
                    onPrevious: {
                        guard let previousID = previousPreviewImageID(for: uuid) else { return }
                        openImagePreview(uuid: previousID)
                    },
                    onNext: {
                        guard let nextID = nextPreviewImageID(for: uuid) else { return }
                        openImagePreview(uuid: nextID)
                    }
                )

                if let panel = existingPanel {
                    panel.orderFront(nil)
                } else {
                    let screenFrame = targetScreen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
                    let panelSize = previousPanelSize ?? NSSize(
                        width: min(max(screenFrame.width * 0.72, 760), 1280),
                        height: min(max(screenFrame.height * 0.72, 560), 960)
                    )
                    let centeredOrigin = NSPoint(
                        x: screenFrame.midX - panelSize.width / 2,
                        y: screenFrame.midY - panelSize.height / 2
                    )

                    let panel = NSPanel(
                        contentRect: NSRect(origin: .zero, size: panelSize),
                        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false
                    )
                    panel.title = "图片预览"
                    panel.level = .floating
                    panel.isFloatingPanel = true
                    panel.isReleasedWhenClosed = false
                    panel.becomesKeyOnlyIfNeeded = true
                    panel.hidesOnDeactivate = false
                    panel.worksWhenModal = true
                    panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
                    panel.minSize = NSSize(width: 420, height: 320)

                    let hosting = NSHostingController(rootView: ImagePreviewView(state: imagePreviewState))
                    hosting.sizingOptions = []
                    panel.contentViewController = hosting
                    panel.setFrame(NSRect(origin: centeredOrigin, size: panelSize), display: true)

                    if let parentWindow {
                        parentWindow.addChildWindow(panel, ordered: .above)
                        imagePreviewParentWindowNumber = parentWindow.windowNumber
                        panel.orderFront(nil)
                    } else {
                        panel.orderFrontRegardless()
                        imagePreviewParentWindowNumber = nil
                    }

                    imagePreviewPanel = panel
                }
                imagePreviewTask = nil
            }
        }
    }

    @MainActor
    func closeImagePreviewPanel() {
        if let panel = imagePreviewPanel {
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            } else if let parentWindowNumber = imagePreviewParentWindowNumber,
                      let parent = NSApp.windows.first(where: { $0.windowNumber == parentWindowNumber }) {
                parent.removeChildWindow(panel)
            }
            panel.close()
        }
        imagePreviewPanel = nil
        imagePreviewParentWindowNumber = nil
        currentPreviewImageID = nil
    }

    @MainActor
    func imagePreviewScreen() -> NSScreen? {
        if let panel = imagePreviewPanel, let screen = panel.screen {
            return screen
        }
        if let keyWindow = NSApp.keyWindow, let screen = keyWindow.screen {
            return screen
        }
        if let mainWindow = NSApp.mainWindow, let screen = mainWindow.screen {
            return screen
        }
        return NSScreen.main
    }

    var previewImagesForCurrentTopic: [NoteImage] {
        let orderedIDs = previewImageIDsInDraftOrder
        guard !orderedIDs.isEmpty else { return [] }

        let imagesByID = Dictionary(uniqueKeysWithValues: noteImages.map { ($0.id, $0) })
        return orderedIDs.compactMap { imagesByID[$0] }
    }

    var previewImageIDsInDraftOrder: [UUID] {
        let pattern = #"\[IMG:([0-9A-Fa-f\-]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(draftNote.startIndex..., in: draftNote)
        let matches = regex.matches(in: draftNote, range: range)
        return matches.compactMap { match in
            guard let uuidRange = Range(match.range(at: 1), in: draftNote) else { return nil }
            return UUID(uuidString: String(draftNote[uuidRange]))
        }
    }

    func previousPreviewImageID(for imageID: UUID) -> UUID? {
        guard let index = previewImagesForCurrentTopic.firstIndex(where: { $0.id == imageID }), index > 0 else {
            return nil
        }
        return previewImagesForCurrentTopic[index - 1].id
    }

    func nextPreviewImageID(for imageID: UUID) -> UUID? {
        guard let index = previewImagesForCurrentTopic.firstIndex(where: { $0.id == imageID }) else {
            return nil
        }
        let nextIndex = index + 1
        guard previewImagesForCurrentTopic.indices.contains(nextIndex) else { return nil }
        return previewImagesForCurrentTopic[nextIndex].id
    }
}
