//
//  UpdateProvider.swift
//  Promtier
//
//  SERVICIO: Maneja las actualizaciones automáticas con Sparkle (Ruta B)
//

import Foundation
import Sparkle
import SwiftUI
import Combine

class UpdateProvider: ObservableObject {
    static let shared = UpdateProvider()
    
    // El controlador oficial de Sparkle
    private let updaterController: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates = false
    
    init() {
        // Inicializamos el controlador de Sparkle
        // Nota: updaterDelegate puede ser nil para comportamiento estándar
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Observamos si el updater está listo
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// Lanza la ventana de búsqueda de actualizaciones
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
