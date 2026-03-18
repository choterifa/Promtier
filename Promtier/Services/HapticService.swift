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
        guard PreferencesManager.shared.hapticFeedbackEnabled else { return }
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    
    /// Genera un feedback de alineación (para resizing o cuando algo 'encaja')
    func playAlignment() {
        guard PreferencesManager.shared.hapticFeedbackEnabled else { return }
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
    
    /// Genera un feedback de nivel (para cambios de tamaño o incrementos continuos)
    func playImpact() {
        guard PreferencesManager.shared.hapticFeedbackEnabled else { return }
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
    
    /// Genera un feedback fuerte (para pruebas o errores críticos)
    func playStrong() {
        guard PreferencesManager.shared.hapticFeedbackEnabled else { return }
        DispatchQueue.main.async {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.alignment, performanceTime: .now)
            // Pequeño delay y otro para que se note
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                performer.perform(.alignment, performanceTime: .now)
            }
        }
    }
    
    /// Genera un feedback de éxito
    func playSuccess() {
        guard PreferencesManager.shared.hapticFeedbackEnabled else { return }
        DispatchQueue.main.async {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.generic, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                performer.perform(.generic, performanceTime: .now)
            }
        }
    }
    
    /// Genera un feedback de error
    func playError() {
        guard PreferencesManager.shared.hapticFeedbackEnabled else { return }
        DispatchQueue.main.async {
            let performer = NSHapticFeedbackManager.defaultPerformer
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    performer.perform(.alignment, performanceTime: .now)
                }
            }
        }
    }
}
