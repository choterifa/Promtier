//
//  TemplateVariable.swift
//  Promtier
//
//  MODELO DE VARIABLE: Para plantillas dinámicas con placeholders
//  Created by Carlos on 15/03/26.
//

import Foundation

// MODELO DE VARIABLE: Para plantillas dinámicas
struct TemplateVariable: Identifiable, Codable, Hashable {
    let id: UUID                    // Identificador único
    var name: String                // Nombre de variable ({{nombre}})
    var defaultValue: String?        // Valor por defecto
    var isRequired: Bool            // Si es obligatoria
    var placeholder: String?         // Texto de ayuda para el usuario
    
    // Inicializador con valores por defecto
    init(name: String, defaultValue: String? = nil, isRequired: Bool = false, placeholder: String? = nil) {
        self.id = UUID()
        self.name = name
        self.defaultValue = defaultValue
        self.isRequired = isRequired
        self.placeholder = placeholder
    }
    
    // MARK: - Métodos de ayuda
    
    /// Genera el placeholder completo para la UI
    var displayPlaceholder: String {
        return placeholder ?? "Ingresa valor para \(name)" // CONFIGURABLE: Texto por defecto
    }
    
    /// Verifica si la variable tiene un valor válido
    func isValid(value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return !isRequired // CONFIGURABLE: Permitir vacío si no es requerido
        }
        return !value.isEmpty
    }
}
