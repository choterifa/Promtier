//
//  DiffEngine.swift
//  Promtier
//
//  UTIL: Motor de diferenciación visual para comparar textos.
//  Proporciona comparación tanto por palabras como por líneas (estilo git).
//

import Foundation
import SwiftUI

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

struct LineDiff: Identifiable {
    let id = UUID()
    let text: String
    let type: DiffType
    let lineNumber: Int?
}

class DiffEngine {
    
    /// Compara dos textos línea por línea (estilo git) y devuelve una lista de LineDiff.
    static func computeLineDiff(oldText: String, newText: String) -> [LineDiff] {
        let oldLines = oldText.components(separatedBy: .newlines)
        let newLines = newText.components(separatedBy: .newlines)
        
        var result: [LineDiff] = []
        
        let matrix = lcsMatrix(oldLines, newLines)
        var i = oldLines.count
        var j = newLines.count
        
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i-1] == newLines[j-1] {
                result.insert(LineDiff(text: oldLines[i-1], type: .unchanged, lineNumber: i), at: 0)
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || matrix[i][j-1] >= matrix[i-1][j]) {
                result.insert(LineDiff(text: newLines[j-1], type: .added, lineNumber: j), at: 0)
                j -= 1
            } else if i > 0 && (j == 0 || matrix[i][j-1] < matrix[i-1][j]) {
                result.insert(LineDiff(text: oldLines[i-1], type: .removed, lineNumber: i), at: 0)
                i -= 1
            }
        }
        
        return result
    }
    
    private static func lcsMatrix(_ a: [String], _ b: [String]) -> [[Int]] {
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1] + 1
                } else {
                    matrix[i][j] = max(matrix[i-1][j], matrix[i][j-1])
                }
            }
        }
        return matrix
    }
    
    /// Compara dos textos palabra por palabra y devuelve una lista de tokens con su estado.
    static func computeDiff(oldText: String, newText: String) -> [DiffToken] {
        let oldWords = oldText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = newText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        var result: [DiffToken] = []
        
        var oldIdx = 0
        var newIdx = 0
        
        while oldIdx < oldWords.count || newIdx < newWords.count {
            if oldIdx < oldWords.count && newIdx < newWords.count {
                if oldWords[oldIdx] == newWords[newIdx] {
                    result.append(DiffToken(text: oldWords[oldIdx], type: .unchanged))
                    oldIdx += 1
                    newIdx += 1
                } else {
                    if let nextMatchInNew = findNextMatch(word: oldWords[oldIdx], in: newWords, startingAt: newIdx) {
                        for i in newIdx..<nextMatchInNew {
                            result.append(DiffToken(text: newWords[i], type: .added))
                        }
                        newIdx = nextMatchInNew
                    } else {
                        result.append(DiffToken(text: oldWords[oldIdx], type: .removed))
                        oldIdx += 1
                    }
                }
            } else if oldIdx < oldWords.count {
                result.append(DiffToken(text: oldWords[oldIdx], type: .removed))
                oldIdx += 1
            } else if newIdx < newWords.count {
                result.append(DiffToken(text: newWords[newIdx], type: .added))
                newIdx += 1
            }
        }
        
        return result
    }
    
    private static func findNextMatch(word: String, in words: [String], startingAt: Int) -> Int? {
        let limit = min(startingAt + 50, words.count)
        for i in startingAt..<limit {
            if words[i] == word { return i }
        }
        return nil
    }
}
