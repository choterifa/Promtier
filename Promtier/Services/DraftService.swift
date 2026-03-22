//
//  DraftService.swift
//  Promtier
//
//  SERVICIO: Persistencia de borradores para la creación/edición de prompts
//  Created by Carlos on 18/03/26.
//

import Foundation
import Combine

class DraftService: ObservableObject {
    static let shared = DraftService()
    private let userDefaults = UserDefaults.standard
    private let draftKey = "promptDraft"
    private let isEditingKey = "isEditingDraft"
    
    @Published var hasDraft: Bool = false
    
    private init() {
        self.hasDraft = userDefaults.data(forKey: draftKey) != nil
    }
    
    /// Guarda el estado actual del prompt como un borrador
    func saveDraft(prompt: Prompt, isEditing: Bool) {
        // No guardar si el borrador está completamente vacío
        let isNegativeEmpty = prompt.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        let areAlternativesEmpty = prompt.alternatives.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        if prompt.title.isEmpty &&
            prompt.content.isEmpty &&
            (prompt.promptDescription?.isEmpty ?? true) &&
            isNegativeEmpty &&
            areAlternativesEmpty &&
            prompt.showcaseImages.isEmpty {
            clearDraft()
            return
        }
        
        if let encoded = try? JSONEncoder().encode(prompt) {
            userDefaults.set(encoded, forKey: draftKey)
            userDefaults.set(isEditing, forKey: isEditingKey)
            DispatchQueue.main.async {
                self.hasDraft = true
            }
        }
    }
    
    /// Carga el borrador guardado si existe
    func loadDraft() -> (prompt: Prompt, isEditing: Bool)? {
        guard let data = userDefaults.data(forKey: draftKey),
              let prompt = try? JSONDecoder().decode(Prompt.self, from: data) else {
            return nil
        }
        let isEditing = userDefaults.bool(forKey: isEditingKey)
        return (prompt, isEditing)
    }
    
    /// Elimina el borrador guardado
    func clearDraft() {
        userDefaults.removeObject(forKey: draftKey)
        userDefaults.removeObject(forKey: isEditingKey)
        DispatchQueue.main.async {
            self.hasDraft = false
        }
    }
}
