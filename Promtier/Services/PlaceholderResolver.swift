//
//  PlaceholderResolver.swift
//  Promtier
//
//  SERVICIO: Resolución automatizada de variables dinámicas {{clipboard}}, {{date}}, etc.
//

import Foundation
import AppKit

class PlaceholderResolver {
    static let shared = PlaceholderResolver()
    
    private init() {}
    
    /// Lista de identificadores que son considerados "Smart" (Auto-rellenables)
    static let smartIdentifiers: Set<String> = [
        "clipboard", "portapapeles",
        "date", "fecha",
        "time", "hora",
        "day", "dia",
        "app_name", "app", "aplicacion"
    ]
    
    /// Resuelve un identificador de variable a su valor actual del sistema
    func resolve(_ identifier: String) -> String? {
        let lower = identifier.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 1. Clipboard
        if lower == "clipboard" || lower == "portapapeles" {
            return NSPasteboard.general.string(forType: .string) ?? ""
        }
        
        // 2. Date
        if lower == "date" || lower == "fecha" {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: Date())
        }
        
        // 3. Time
        if lower == "time" || lower == "hora" {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: Date())
        }
        
        // 4. Day
        if lower == "day" || lower == "dia" {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Nombre completo del día
            return formatter.string(from: Date())
        }
        
        // 5. App Name (Context Aware)
        if lower == "app_name" || lower == "app" || lower == "aplicacion" {
            if let bundleID = ClipboardService.shared.lastSourceAppBundleID {
                // Intentar obtener el nombre legible si está disponible
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    let appName = appURL.deletingPathExtension().lastPathComponent
                    return appName
                }
                return bundleID
            }
            return "General"
        }
        
        return nil
    }
    
    /// Resuelve todos los placeholders inteligentes dentro de una cadena de texto
    func resolveAll(in text: String) -> String {
        var result = text
        let vars = extractVariables(from: text)
        
        for v in vars {
            if let resolved = resolve(v) {
                let escapedVar = NSRegularExpression.escapedPattern(for: v)
                let pattern = "\\{\\{\\s*\(escapedVar)\\s*\\}\\}\\$|\\{\\{\\s*\(escapedVar)\\s*\\}\\}"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(result.startIndex..<result.endIndex, in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: resolved)
                }
            }
        }
        return result
    }
    
    /// Resuelve recursivamente los encadenamientos [[@Prompt:Nombre]]
    func resolveChains(in text: String, availablePrompts: [Prompt], depth: Int = 0) -> String {
        if depth > 5 { return text } // Evitar recursión infinita
        
        var result = text
        let regex = Prompt.chainExtractRegex
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        var matches: [(String, NSRange)] = []
        regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let fullRange = match?.range(at: 0),
               let captureRange = match?.range(at: 1) {
                let name = (text as NSString).substring(with: captureRange)
                matches.append((name.trimmingCharacters(in: .whitespacesAndNewlines), fullRange))
            }
        }
        
        // Reemplazar de atrás hacia adelante para no invalidar los rangos
        for (name, fullRange) in matches.reversed() {
            if let linked = availablePrompts.first(where: { $0.title.lowercased() == name.lowercased() }) {
                // Resolver cadenas del hijo primero
                let resolvedLinked = resolveChains(in: linked.content, availablePrompts: availablePrompts, depth: depth + 1)
                
                if let range = Range(fullRange, in: result) {
                    result.replaceSubrange(range, with: resolvedLinked)
                }
            }
        }
        
        return result
    }
    
    private func extractVariables(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var matches: [String] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let captureRange = match?.range(at: 1),
               let name = (text as NSString).substring(with: captureRange) as String? {
                matches.append(name.trimmingCharacters(in: .whitespaces))
            }
        }
        return matches
    }
    
    /// Verifica si un identificador es una variable inteligente
    static func isSmart(_ identifier: String) -> Bool {
        let lower = identifier.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Soporte para prefijos de fecha opcionales o nombres exactos
        if smartIdentifiers.contains(lower) { return true }
        
        // Casos especiales (ej: date:full, date:short)
        if lower.hasPrefix("date:") || lower.hasPrefix("fecha:") || 
           lower.hasPrefix("time:") || lower.hasPrefix("hora:") {
            return true
        }
        
        return false
    }
}
