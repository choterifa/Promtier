//
//  MagicAnalysisStage.swift
//  Promtier
//

import Foundation

enum MagicAnalysisStage: Equatable {
    case idle
    case decoding
    case analyzing
    case generating
    case populating
    case completed

    var label: String {
        switch self {
        case .idle:       return ""
        case .decoding:   return "Decodificando imagen…"
        case .analyzing:  return "Analizando composición…"
        case .generating: return "Generando prompt con IA…"
        case .populating: return "Aplicando resultados…"
        case .completed:  return "¡Análisis completado!"
        }
    }

    var progress: Double {
        switch self {
        case .idle:       return 0.0
        case .decoding:   return 0.15
        case .analyzing:  return 0.35
        case .generating: return 0.75
        case .populating: return 0.90
        case .completed:  return 1.0
        }
    }

    var isActive: Bool { self != .idle }
}
