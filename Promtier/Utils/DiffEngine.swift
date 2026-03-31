//
//  DiffEngine.swift
//  Promtier
//
//  UTIL: Motor de diferenciación visual simple (Diff) para comparar textos.
//

import Foundation

enum DiffType {
    case added
    case removed
    case unchanged
}

struct DiffToken: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: DiffType
}

class DiffEngine {
    
    /// Compara dos textos palabra por palabra y devuelve una lista de tokens con su estado.
    /// Utiliza un enfoque simplificado para legibilidad y rendimiento en prompts.
    static func computeDiff(oldText: String, newText: String) -> [DiffToken] {
        let oldWords = oldText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = newText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        var result: [DiffToken] = []
        
        // Algoritmo de comparación simple (O(n*m) simplificado para mejor UX)
        // Nota: Un diff real (LCS) sería más preciso, pero para prompts, 
        // ver qué se añadió al final o qué cambió suele ser suficiente con un enfoque voraz.
        
        var oldIdx = 0
        var newIdx = 0
        
        while oldIdx < oldWords.count || newIdx < newWords.count {
            if oldIdx < oldWords.count && newIdx < newWords.count {
                if oldWords[oldIdx] == newWords[newIdx] {
                    // Texto sin cambios
                    result.append(DiffToken(text: oldWords[oldIdx], type: .unchanged))
                    oldIdx += 1
                    newIdx += 1
                } else {
                    // ¿Es una adición o una eliminación?
                    // Buscamos si la palabra actual de 'new' aparece más adelante en 'old'
                    if let nextMatchInNew = findNextMatch(word: oldWords[oldIdx], in: newWords, startingAt: newIdx) {
                        // Se han añadido palabras antes de encontrar el match
                        for i in newIdx..<nextMatchInNew {
                            result.append(DiffToken(text: newWords[i], type: .added))
                        }
                        newIdx = nextMatchInNew
                    } else {
                        // La palabra actual de 'old' no está adelante en 'new', se eliminó
                        result.append(DiffToken(text: oldWords[oldIdx], type: .removed))
                        oldIdx += 1
                    }
                }
            } else if oldIdx < oldWords.count {
                // Solo quedan palabras en el texto viejo
                result.append(DiffToken(text: oldWords[oldIdx], type: .removed))
                oldIdx += 1
            } else if newIdx < newWords.count {
                // Solo quedan palabras en el texto nuevo
                result.append(DiffToken(text: newWords[newIdx], type: .added))
                newIdx += 1
            }
        }
        
        return result
    }
    
    private static func findNextMatch(word: String, in words: [String], startingAt: Int) -> Int? {
        // Limitar la búsqueda hacia adelante para evitar O(n^2) excesivo en textos gigantes
        let limit = min(startingAt + 50, words.count)
        for i in startingAt..<limit {
            if words[i] == word { return i }
        }
        return nil
    }
}
