//
//  AutoBackupService.swift
//  Promtier
//
//  SERVICIO: Gestión de copias de seguridad automáticas diarias.
//  Created by Antigravity on 24/04/24.
//

import Foundation

class AutoBackupService {
    static let shared = AutoBackupService()
    
    private let fileManager = FileManager.default
    private let lastBackupKey = "last_auto_backup_date"
    private let backupsToKeep = 7 // Mantener la última semana
    
    private var backupsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport.appendingPathComponent("AutoBackups", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    private init() {}
    
    /// Ejecuta el proceso de backup si ha pasado más de un día desde el último.
    func performAutoBackupIfNeeded() {
        let now = Date()
        
        if let lastBackup = UserDefaults.standard.object(forKey: lastBackupKey) as? Date {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour], from: lastBackup, to: now)
            
            // Solo si han pasado 24 horas
            guard let hours = components.hour, hours >= 24 else {
                return
            }
        }
        
        print("🕒 Iniciando auto-backup programado...")
        executeBackup()
    }
    
    private func executeBackup() {
        DispatchQueue.global(qos: .background).async {
            // 1. Obtener los datos en JSON usando el exportador existente
            guard let backupData = PromptService.shared.exportAllPromptsAsJSON() else {
                print("❌ Falló la generación del auto-backup")
                return
            }
            
            // 2. Crear nombre de archivo con fecha
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: Date())
            let fileName = "promtier_backup_\(dateString).json"
            let fileURL = self.backupsDirectory.appendingPathComponent(fileName)
            
            do {
                // 3. Guardar el archivo
                try backupData.write(to: fileURL, options: .atomic)
                print("✅ Auto-backup guardado en: \(fileURL.lastPathComponent)")
                
                // 4. Actualizar fecha de último backup exitoso
                UserDefaults.standard.set(Date(), forKey: self.lastBackupKey)
                
                // 5. Limpieza selectiva (Pruning)
                self.pruneOldBackups()
                
            } catch {
                print("❌ Error escribiendo auto-backup: \(error)")
            }
        }
    }
    
    private func pruneOldBackups() {
        do {
            let files = try fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Ordenar por fecha de creación (los más antiguos primero)
            let sortedFiles = files.sorted {
                let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // Eliminar si hay más de los permitidos
            if sortedFiles.count > backupsToKeep {
                let toDelete = sortedFiles.count - backupsToKeep
                for i in 0..<toDelete {
                    try fileManager.removeItem(at: sortedFiles[i])
                    print("🧹 Eliminado backup antiguo: \(sortedFiles[i].lastPathComponent)")
                }
            }
        } catch {
            print("❌ Error limpiando backups antiguos: \(error)")
        }
    }
}

extension PromptService {
    /// Puente para acceder al exportador desde el servicio de backup
    func exportAllPromptsAsJSON() -> Data? {
        return self.exportService.exportAllPromptsAsJSON()
    }
}
