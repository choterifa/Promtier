import UniformTypeIdentifiers

extension UTType {
    // Usar `exportedAs` para evitar fallback a `public.data` (rompe detección en drop)
    static let promtierPromptId = UTType(exportedAs: "com.promtier.prompt.id")
    static let promtierPromptIds = UTType(exportedAs: "com.promtier.prompt.ids")
    static let promtierFolderId = UTType(exportedAs: "com.promtier.folder.id")
}
