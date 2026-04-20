import AppKit

struct NewPromptShortcutRouter {
    func route(
        event: NSEvent,
        modifiers: NSEvent.ModifierFlags,
        overlayNavigation: (NSEvent) -> Bool,
        galleryNavigation: (NSEvent) -> Bool,
        spacePreview: (NSEvent) -> Bool,
        save: (NSEvent.ModifierFlags, NSEvent) -> Bool,
        copy: (NSEvent.ModifierFlags, NSEvent) -> Bool,
        pasteImage: (NSEvent.ModifierFlags, NSEvent) -> Bool,
        escape: (NSEvent) -> Bool,
        quickFocus: (NSEvent.ModifierFlags, NSEvent) -> Bool
    ) -> Bool {
        // Keep deterministic priority: overlay interactions first, then gallery/media,
        // then save/copy/paste actions, and finally global escape/focus shortcuts.
        overlayNavigation(event)
            || galleryNavigation(event)
            || spacePreview(event)
            || save(modifiers, event)
            || copy(modifiers, event)
            || pasteImage(modifiers, event)
            || escape(event)
            || quickFocus(modifiers, event)
    }
}
