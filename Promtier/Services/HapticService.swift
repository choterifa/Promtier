//
//  HapticService.swift
//  Promtier
//
//  SERVICIO: Retroalimentación háptica para trackpads (Force Touch)
//

import AppKit

class HapticService {
    static let shared = HapticService()
    
    private init() {}
    
    /// Genera un "click" genérico suave (para botones, toggles)
    func playLight() {
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    
    /// Genera un feedback de alineación (para resizing o cuando algo 'encaja')
    func playAlignment() {
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
    
    /// Genera un feedback de nivel (para cambios de tamaño o incrementos continuos)
    func playImpact() {
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
    
    /// Genera un feedback fuerte (para pruebas o errores críticos)
    func playStrong() {
        DispatchQueue.main.async {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.alignment, performanceTime: .now)
            // Pequeño delay y otro para que se note
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                performer.perform(.alignment, performanceTime: .now)
            }
        }
    }
}
