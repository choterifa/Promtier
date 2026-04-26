//
//  LocalModelDownloadManager.swift
//  Promtier
//
//  SERVICIO: Gestor de descargas para modelos locales de IA
//

import Foundation
import Combine

enum DownloadState: Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(String)
}

extension DownloadState: Equatable {
    nonisolated static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded): return true
        case (.downloaded, .downloaded): return true
        case let (.downloading(p1), .downloading(p2)): return p1 == p2
        case let (.error(e1), .error(e2)): return e1 == e2
        default: return false
        }
    }
}

class LocalModelDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = LocalModelDownloadManager()
    
    @Published var modelStates: [String: DownloadState] = [:]
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.valencia.promtier.modeldownloads")
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // Carpeta donde guardaremos los modelos
    var modelsDirectoryURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("Promtier/Models", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appSupportDir
    }
    
    private override init() {
        super.init()
        checkExistingModels()
    }
    
    func checkExistingModels() {
        for model in LocalModel.availableModels {
            let fileURL = modelsDirectoryURL.appendingPathComponent(model.filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                DispatchQueue.main.async {
                    self.modelStates[model.id] = .downloaded
                }
            } else {
                if self.modelStates[model.id] == nil || self.modelStates[model.id] == .downloaded {
                    DispatchQueue.main.async {
                        self.modelStates[model.id] = .notDownloaded
                    }
                }
            }
        }
    }
    
    func getDownloadedModels() -> [LocalModel] {
        return LocalModel.availableModels.filter { modelStates[$0.id] == .downloaded }
    }
    
    func getBestDownloadedModel() -> LocalModel? {
        let downloaded = getDownloadedModels()
        // Priorizar el recomendado (Phi-3)
        if let recommended = downloaded.first(where: { $0.recommended }) {
            return recommended
        }
        // Sino, el primero disponible
        return downloaded.first
    }
    
    func downloadModel(_ model: LocalModel) {
        guard modelStates[model.id] != .downloaded, downloadTasks[model.id] == nil else { return }
        
        DispatchQueue.main.async {
            self.modelStates[model.id] = .downloading(progress: 0.0)
        }
        
        let task = urlSession.downloadTask(with: model.downloadURL)
        task.taskDescription = model.id
        downloadTasks[model.id] = task
        task.resume()
    }
    
    func cancelDownload(for model: LocalModel) {
        if let task = downloadTasks[model.id] {
            task.cancel()
            downloadTasks.removeValue(forKey: model.id)
            DispatchQueue.main.async {
                self.modelStates[model.id] = .notDownloaded
            }
        }
    }
    
    func deleteModel(_ model: LocalModel) {
        let fileURL = modelsDirectoryURL.appendingPathComponent(model.filename)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            DispatchQueue.main.async {
                self.modelStates[model.id] = .notDownloaded
            }
        } catch {
            print("Error deleting model: \(error)")
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let modelId = downloadTask.taskDescription else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            if case .downloading = self.modelStates[modelId] {
                // Throttle UI updates implicitly or explicitly
                self.modelStates[modelId] = .downloading(progress: progress)
            } else if self.modelStates[modelId] == nil || self.modelStates[modelId] == .notDownloaded {
                self.modelStates[modelId] = .downloading(progress: progress)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelId = downloadTask.taskDescription,
              let model = LocalModel.availableModels.first(where: { $0.id == modelId }) else { return }
        
        let destinationURL = modelsDirectoryURL.appendingPathComponent(model.filename)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.modelStates[modelId] = .downloaded
                self.downloadTasks.removeValue(forKey: modelId)
            }
        } catch {
            DispatchQueue.main.async {
                self.modelStates[modelId] = .error(error.localizedDescription)
                self.downloadTasks.removeValue(forKey: modelId)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error, let modelId = task.taskDescription else { return }
        let nsError = error as NSError
        
        // Ignorar el error si la tarea fue cancelada a propósito
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        
        DispatchQueue.main.async {
            self.modelStates[modelId] = .error(error.localizedDescription)
            self.downloadTasks.removeValue(forKey: modelId)
        }
    }
}
