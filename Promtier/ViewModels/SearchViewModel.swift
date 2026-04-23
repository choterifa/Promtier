import SwiftUI
import Combine
import AppKit

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var selectedPrompt: Prompt?
    @Published var showingPreview = false
    @Published var fillingVariablesFor: Prompt?
    @Published var isNavigatingWithKeys: Bool = false
    @Published var showParticles: Bool = false
    
    // Import state
    @Published var isDraggingFile: Bool = false
    @Published var importMessage: String? = nil
    @Published var showingImportAlert: Bool = false
    @Published var importData: Data? = nil
    @Published var importURL: URL? = nil
    
    @Published var isFullScreenImageOpen: Bool = false
    
    // Ghost Tips State
    @Published var currentGhostTip: GhostTip? = nil
    @Published var isGhostTipSuppressedByClipboard = false
    
    func resetSelection() {
        selectedPrompt = nil
        showingPreview = false
    }
    
    func prepareImport(data: Data?, url: URL?) {
        self.importData = data
        self.importURL = url
        self.showingImportAlert = true
    }
}
