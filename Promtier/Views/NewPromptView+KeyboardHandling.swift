import SwiftUI
import AppKit

extension NewPromptView {
    
    func setupKeyboardMonitor() {
        keyboardCoordinator.start { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            return self.shortcutRouter.route(
                event: event,
                modifiers: modifiers,
                overlayNavigation: { self.handleOverlayNavigationShortcut(event: $0) },
                galleryNavigation: { self.handleImageGalleryArrowShortcut(event: $0) },
                spacePreview: { self.handleSpacePreviewShortcut(event: $0) },
                save: { self.handleSaveShortcut(modifiers: $0, event: $1) },
                copy: { self.handleCopyShortcut(modifiers: $0, event: $1) },
                pasteImage: { self.handlePasteImageShortcut(modifiers: $0, event: $1) },
                escape: { self.handleEscapeShortcut(event: $0) },
                quickFocus: { self.handleQuickFocusShortcut(modifiers: $0, event: $1) }
            )
        }
    }

    func handleOverlayListNavigation(
        event: NSEvent,
        isVisible: Bool,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void,
        select: @escaping () -> Void
    ) -> Bool {
        guard isVisible else { return false }

        switch event.keyCode {
        case ShortcutKeyCode.upArrow:
            DispatchQueue.main.async { moveUp() }
            return true
        case ShortcutKeyCode.downArrow:
            DispatchQueue.main.async { moveDown() }
            return true
        case ShortcutKeyCode.returnKey, ShortcutKeyCode.enterKey:
            DispatchQueue.main.async { select() }
            return true
        default:
            return false
        }
    }

    func presentField(_ showAction: @escaping () -> Void, focusAction: @escaping () -> Void) {
        DispatchQueue.main.async {
            withAnimation(.spring()) {
                showAction()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusAction()
            }
        }
    }

    func handleOptionVariableShortcut() {
        DispatchQueue.main.async {
            if self.preferences.isPremiumActive {
                withAnimation {
                    self.showVariables.toggle()
                    self.variablesSelectedIndex = 0
                }
            } else {
                self.showingPremiumFor = "dynamic_variables".localized(for: self.preferences.language)
            }
        }
    }

    func handleOverlayNavigationShortcut(event: NSEvent) -> Bool {
        if handleOverlayListNavigation(
            event: event,
            isVisible: showVariables,
            moveUp: { self.variablesSelectedIndex = max(0, self.variablesSelectedIndex - 1) },
            moveDown: { self.variablesSelectedIndex += 1 },
            select: { self.triggerVariablesSelection = true }
        ) {
            return true
        }

        return handleOverlayListNavigation(
            event: event,
            isVisible: showSnippets,
            moveUp: { self.snippetSelectedIndex = max(0, self.snippetSelectedIndex - 1) },
            moveDown: { self.snippetSelectedIndex += 1 },
            select: { self.triggerSnippetSelection = true }
        )
    }

    func handleImageGalleryArrowShortcut(event: NSEvent) -> Bool {
        guard !showcaseImages.isEmpty, !isTextInputFocused else { return false }

        if event.keyCode == ShortcutKeyCode.leftArrow {
            DispatchQueue.main.async {
                self.mediaState.selectedImageIndex = max(0, self.mediaState.selectedImageIndex - 1)
                if self.mediaState.fullScreenImageData != nil {
                    self.mediaState.fullScreenImageData = self.showcaseImages[self.mediaState.selectedImageIndex]
                }
            }
            return true
        }

        if event.keyCode == ShortcutKeyCode.rightArrow {
            DispatchQueue.main.async {
                self.mediaState.selectedImageIndex = min(self.showcaseImages.count - 1, self.mediaState.selectedImageIndex + 1)
                if self.mediaState.fullScreenImageData != nil {
                    self.mediaState.fullScreenImageData = self.showcaseImages[self.mediaState.selectedImageIndex]
                }
            }
            return true
        }

        return false
    }

    func handleSpacePreviewShortcut(event: NSEvent) -> Bool {
        guard event.keyCode == ShortcutKeyCode.space else { return false }
        guard !isTextInputFocused || mediaState.fullScreenImageData != nil else { return false }

        DispatchQueue.main.async {
            if self.mediaState.fullScreenImageData != nil {
                withAnimation(.spring(response: 0.3)) {
                    self.mediaState.fullScreenImageData = nil
                }
            } else if !self.showcaseImages.isEmpty {
                let idx = min(self.mediaState.selectedImageIndex, self.showcaseImages.count - 1)
                self.mediaState.selectedImageIndex = idx
                withAnimation(.spring(response: 0.35)) {
                    self.mediaState.fullScreenImageData = self.showcaseImages[idx]
                }
                if self.preferences.soundEnabled { SoundService.shared.playPreviewSound() }
            }
        }
        return true
    }

    func handleSaveShortcut(modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        guard modifiers.contains(.command), event.keyCode == ShortcutKeyCode.keyS else { return false }

        DispatchQueue.main.async {
            let trimmedTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedContent = self.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedTitle.isEmpty && !trimmedContent.isEmpty else {
                HapticService.shared.playError()
                self.showTransientBranchMessage("required_fields".localized(for: self.preferences.language), duration: 3.0)
                return
            }

            if self.showingZenEditor {
                self.savePrompt(closeAfter: false)
                withAnimation(.spring()) {
                    self.zenTarget = nil
                    self.showingZenEditor = false
                }
            } else {
                self.savePrompt()
            }
        }
        return true
    }

    func handleCopyShortcut(modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        guard modifiers == .command, event.keyCode == ShortcutKeyCode.keyC else { return false }
        guard !isTextSelectedInEditor(), !content.isEmpty else { return false }

        DispatchQueue.main.async {
            ClipboardService.shared.copyToClipboard(self.content)
            if self.preferences.soundEnabled { SoundService.shared.playCopySound() }
            HapticService.shared.playLight()
        }
        return true
    }

    func handlePasteImageShortcut(modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        guard modifiers == .command, event.keyCode == ShortcutKeyCode.keyV else { return false }

        guard showcaseImages.count < PromptMediaImportPipeline.maxSlots else {
            showImageImportWarning(imageSlotsFullMessage)
            return true
        }

        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types,
              types.contains(where: { $0.rawValue.starts(with: "public.image") || $0 == .png || $0 == .tiff }) else {
            return false
        }

        if let pbData = pasteboard.data(forType: .png)
            ?? pasteboard.data(forType: .tiff)
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            appendOptimizedImageData(pbData, at: nil)
            return true
        }

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
                self.appendOptimizedImageData(jpegData, at: nil)
            }
            return true
        }

        return false
    }

    func handleEscapeShortcut(event: NSEvent) -> Bool {
        guard event.keyCode == ShortcutKeyCode.escape else { return false }

        if showingMagicOptions {
            DispatchQueue.main.async { withAnimation { self.showingMagicOptions = false } }
            return true
        }

        if showSnippets {
            DispatchQueue.main.async { self.dismissSnippetsOverlay() }
            return true
        }

        if showVariables {
            DispatchQueue.main.async { self.dismissVariablesOverlay() }
            return true
        }

        if zenTarget == nil && !showingIconPicker {
            if let window = NSApp.keyWindow, let firstResponder = window.firstResponder {
                let isEditingText = firstResponder is NSTextView || firstResponder.className.contains("TextEditor")
                if isEditingText {
                    DispatchQueue.main.async {
                        _ = window.makeFirstResponder(nil)
                    }
                    return true
                }
            }

            DispatchQueue.main.async {
                if self.hasUnsavedChanges {
                    self.showingCloseAlert = true
                } else {
                    self.discardChanges()
                }
            }
            return true
        }

        if zenTarget != nil {
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.zenTarget = nil
                    self.showingZenEditor = false
                }
            }
            return true
        }

        return false
    }

    func handleQuickFocusShortcut(modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        if modifiers == .option && event.keyCode == ShortcutKeyCode.keyN {
            presentField(
                { self.showNegativeField = true },
                focusAction: { self.focusNegative = true }
            )
            return true
        }

        if modifiers == .option && event.keyCode == ShortcutKeyCode.keyA {
            presentField(
                { self.showAlternativeField = true },
                focusAction: { self.focusAlternative = true }
            )
            return true
        }

        if modifiers == .option && event.keyCode == ShortcutKeyCode.keyV {
            handleOptionVariableShortcut()
            return true
        }

        return false
    }

}
