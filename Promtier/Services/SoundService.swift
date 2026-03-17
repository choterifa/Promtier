//
//  SoundService.swift
//  Promtier
//
//  SERVICIO: Efectos de sonido del sistema — versión refinada
//  macOS System sounds reference: Basso, Blow, Bottle, Frog, Funk, Glass, Hero,
//  Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
//

import Foundation
import AppKit
import AVFoundation

class SoundService {
    static let shared = SoundService()
    
    private var player: AVAudioPlayer?
    private init() {}
    
    // MARK: - Copiar un prompt
    // "Glass" → campanita cristalina, satisfactoria y corta ✅
    func playCopySound() {
        playSystem("Glass", volume: 0.45)
    }
    
    // MARK: - Vista previa (preview abierto/cerrado)
    // "Pop" → pop suave, sutil ✅
    func playPreviewSound() {
        playSystem("Pop", volume: 0.3)
    }
    
    // MARK: - Eliminar prompt
    // "Funk" → grave y directo, comunica "eliminado" ✅
    func playDeleteSound() {
        playSystem("Funk", volume: 0.38)
    }
    
    // MARK: - Éxito (guardar, crear)
    // "Ping" → corto y positivo ✅
    func playSuccessSound() {
        playSystem("Ping", volume: 0.4)
    }
    
    // MARK: - Favorito marcado/desmarcado
    // "Tink" → muy sutil, metálico ✅
    func playFavoriteSound() {
        playSystem("Tink", volume: 0.5)
    }
    
    // MARK: - Interacción / selección con teclado
    // "Purr" queda bien para nav de lista (imperceptible si el usuario va rápido)
    func playInteractionSound() {
        playSystem("Pop", volume: 0.15)
    }
    
    // MARK: - Error
    func playErrorSound() {
        playSystem("Basso", volume: 0.35)
    }
    
    // MARK: - Mágico / snippet insertado
    func playMagicSound() {
        playSystem("Hero", volume: 0.3)
    }
    
    // MARK: - Interno: reproducir sonido del sistema por nombre
    private func playSystem(_ name: String, volume: Float) {
        if let sound = NSSound(named: name) {
            if sound.isPlaying { sound.stop() }
            sound.volume = volume
            sound.play()
        }
    }
}
