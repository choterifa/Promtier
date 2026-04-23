//
//  BackupArchive.swift
//  Promtier
//
//  Formato de backup “completo” para ZIP (manifest + imágenes en disco).
//

import Foundation

struct BackupArchive: Codable {
    var version: String
    var exportedAt: Date
    var prompts: [Prompt]
    var folders: [Folder]
}

