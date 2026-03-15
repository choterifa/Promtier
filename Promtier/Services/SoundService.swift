//
//  SoundService.swift
//  Promtier
//
//  SERVICIO: Gestión de efectos de sonido personalizados
//  Created by Carlos on 15/03/26.
//

import Foundation
import AppKit

class SoundService {
    static let shared = SoundService()
    
    private init() {}
    
    /// Reproduce un sonido de copia satisfactorio
    func playCopySound() {
        // Usar un sonido del sistema más moderno que NSSound.beep()
        // NSSound(named: "Morse") es un sonido corto y satisfactorio
        if let sound = NSSound(named: "Morse") {
            sound.volume = 0.3
            sound.play()
        } else {
            // Fallback a beep si no encuentra el sonido
            NSSound.beep()
        }
    }
    
    /// Reproduce un sonido de éxito
    func playSuccessSound() {
        if let sound = NSSound(named: "Glass") {
            sound.volume = 0.25
            sound.play()
        } else {
            playCopySound() // Fallback
        }
    }
    
    /// Reproduce un sonido sutil de interacción
    func playInteractionSound() {
        if let sound = NSSound(named: "Pop") {
            sound.volume = 0.2
            sound.play()
        }
    }
    
    /// Reproduce un sonido de error (si es necesario)
    func playErrorSound() {
        if let sound = NSSound(named: "Basso") {
            sound.volume = 0.3
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
