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
    
    // "Submarine" → sonido de burbuja profundo, para copias secundarias ✅
    func playSecondaryCopySound() {
        playSystem("Submarine", volume: 0.45)
    }
    
    // MARK: - Copiar Negative Prompt
    // "Submarine" → sonido de burbuja profundo, comunica algo opuesto o "debajo" ✅
    func playNegativeCopySound() {
        playSystem("Submarine", volume: 0.45)
    }
    
    // MARK: - Copiar Alternative Prompt
    // "Bottle" → sonido corto y hueco, comunica una variante o "otra opción" ✅
    func playAlternativeCopySound() {
        playSystem("Bottle", volume: 0.45)
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
    // "Hero" → sonido especial y positivo para favoritos ✅
    func playFavoriteSound() {
        playSystem("Hero", volume: 0.45)
    }
    
    // MARK: - Interacción / selección con teclado
    // "Purr" queda bien para nav de lista (imperceptible si el usuario va rápido)
    func playInteractionSound() {
        playSystem("Pop", volume: 0.35)
    }
    
    // MARK: - Error
    func playErrorSound() {
        playSystem("Basso", volume: 0.35)
    }
    
    // MARK: - Mágico / snippet insertado
    func playMagicSound() {
        playSystem("Hero", volume: 0.3)
    }
    
    // MARK: - Mover a categoría
    // "Bottle" → sonido de caída satisfactorio ✅
    func playMoveSound() {
        playSystem("Bottle", volume: 0.4)
    }
    
    // MARK: - Interno: reproducir sonido del sistema por nombre
    private func playSystem(_ name: String, volume: Float) {
        // Ejecutar siempre en el hilo principal para NSSound
        DispatchQueue.main.async {
            guard let sound = NSSound(named: name) else { return }
            
            // Si el sonido ya está sonando, creamos una copia o lo reiniciamos
            // para evitar que se corte si se llama varias veces rápido
            if sound.isPlaying {
                // Para sonidos de sistema cortos, solemos disparar y olvidar
                // Si es el mismo, lo detenemos para reiniciar el feedback inmediato
                sound.stop()
            }
            
            sound.volume = volume
            sound.play()
        }
    }
}
