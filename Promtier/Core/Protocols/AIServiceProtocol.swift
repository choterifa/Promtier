//
//  AIServiceProtocol.swift
//  Promtier
//
//  Core: Inyección de Dependencias
//

import Foundation

protocol AIServiceProtocol {
    func generate(prompt: String, imageData: Data?) async throws -> String
    func generatePromptMetadata(title: String, content: String, keepContent: Bool) async throws -> PromptMetadataResponse
}
