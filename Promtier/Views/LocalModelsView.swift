//
//  LocalModelsView.swift
//  Promtier
//
//  VISTA: Catálogo de Modelos Locales Descargables
//

import SwiftUI

struct LocalModelsView: View {
    @StateObject private var downloadManager = LocalModelDownloadManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Modelos Locales (Offline)")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Descarga modelos de IA optimizados para Apple Silicon. Se ejecutan 100% en tu Mac de forma privada y sin coste por token. Úsalos como respaldo o como servicio principal.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            Divider().opacity(0.1)
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(LocalModel.availableModels) { model in
                        LocalModelRow(model: model, state: downloadManager.modelStates[model.id] ?? .notDownloaded)
                    }
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
    }
}

struct LocalModelRow: View {
    let model: LocalModel
    let state: DownloadState
    
    @StateObject private var downloadManager = LocalModelDownloadManager.shared
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.system(size: 14, weight: .bold))
                        
                        if model.recommended {
                            Text("Recomendado")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(model.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Botón de acción
                actionButton
            }
            
            // Footer: Especificaciones
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                    Text("Precisión:")
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(i < model.precisionRating ? Color.primary : Color.primary.opacity(0.2))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("Velocidad:")
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(i < model.speedRating ? Color.primary : Color.primary.opacity(0.2))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive.fill")
                    Text(model.sizeString)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                    Text("Local")
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .notDownloaded, .error:
            Button(action: {
                downloadManager.downloadModel(model)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.down")
                    Text("Descargar")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            if case .error(let msg) = state {
                Text(msg)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .frame(width: 100)
            }
            
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    downloadManager.cancelDownload(for: model)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
        case .downloaded:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("Descargado")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
                
                Button(action: {
                    downloadManager.deleteModel(model)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Borrar modelo")
            }
        }
    }
}
