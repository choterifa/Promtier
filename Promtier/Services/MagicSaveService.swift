import Foundation
import AppKit
import SwiftUI

/// SERVICIO: Orquestador del "Magic Save" (Captura de texto externa -> IA -> Guardado automático)
@MainActor
final class MagicSaveService {
    static let shared = MagicSaveService()
    
    private init() {}
    
    private var isProcessing = false
    
    func executeMagicSave(capturedText: String) {
        guard !isProcessing else { return }
        guard !capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NotificationService.shared.sendNotification(
                title: "Magic Save",
                body: "No se detectó texto seleccionado para guardar."
            )
            return
        }
        
        isProcessing = true
        HapticService.shared.playImpact()
        
        // Notificación de inicio (Feedback táctico)
        NotificationService.shared.sendNotification(
            title: "Magic Save",
            body: "Analizando selección con IA..."
        )
        
        Task {
            do {
                // 1. Generar Metadata con IA
                let metadata = try await AIServiceManager.shared.generatePromptMetadata(title: "", content: capturedText)
                
                // 2. Persistir en CoreData
                let newPrompt = Prompt(
                    title: metadata.title,
                    content: capturedText,
                    promptDescription: metadata.description,
                    folder: nil, // Podríamos intentar clasificarlo también
                    icon: "sparkles",
                    negativePrompt: metadata.negativePrompt
                )
                
                _ = PromptService.shared.createPrompt(newPrompt)
                
                // 3. Feedback de Éxito
                await MainActor.run {
                    self.isProcessing = false
                    HapticService.shared.playSuccess()
                    NotificationService.shared.sendNotification(
                        title: "¡Prompt Guardado!",
                        body: "Se ha añadido '\(metadata.title)' a tu galería.",
                        userInfo: ["promptId": newPrompt.id.uuidString]
                    )
                }
            } catch {
                print("❌ [MagicSaveService] Error procesando con IA: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.isProcessing = false
                    // Fallback: Guardar sin metadata si la IA falla
                    let fallbackTitle = "Magic Save \(Date().formatted(.dateTime.day().month().hour().minute()))"
                    let fallbackPrompt = Prompt(
                        title: fallbackTitle,
                        content: capturedText,
                        folder: "Sin clasificar",
                        icon: "sparkles"
                    )
                    _ = PromptService.shared.createPrompt(fallbackPrompt)
                    
                    HapticService.shared.playError()
                    NotificationService.shared.sendNotification(
                        title: "Guardado (Sin IA)",
                        body: "Error: \(error.localizedDescription.prefix(50))..."
                    )
                }
            }
        }
    }
}
