//
//  DataController.swift
//  Promtier
//
//  SERVICIO PRINCIPAL: Controlador de Core Data para persistencia
//  Created by Carlos on 15/03/26.
//

import CoreData
import Foundation
import Combine

// SERVICIO PRINCIPAL: Controlador de persistencia con Core Data
class DataController: ObservableObject {
    static let shared = DataController()
    private static let modelName = "Promtier"
    
    // Cambiamos 'lazy var' por una propiedad que podamos resetear
    @Published var container: NSPersistentCloudKitContainer
    
    private init() {
        self.container = Self.makeContainer(syncToCloud: PreferencesManager.shared.icloudSyncEnabled)
    }
    
    private static func makeContainer(syncToCloud: Bool) -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: modelName)
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No se encontró la descripción del persistent store")
        }
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        if syncToCloud {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.valencia.Promtier.app")
        } else {
            description.cloudKitContainerOptions = nil
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("❌ Error cargando Core Data: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }
    
    /// Cambia el modo de iCloud y migra los datos si es necesario
    func toggleCloudSync(enabled: Bool) async {
        // 1. Guardar todo lo pendiente antes de cerrar
        save()
        
        // 2. Crear el nuevo contenedor
        let newContainer = Self.makeContainer(syncToCloud: enabled)
        
        // 3. Actualizar la referencia en el hilo principal
        await MainActor.run {
            self.container = newContainer
            // Notificar a los servicios que los datos han cambiado (recargar lista)
            PromptRepository.shared.onDataChanged?()
        }
    }
    
    // Contexto principal para la UI
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    // Contexto de background para operaciones pesadas
    var backgroundContext: NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    // MARK: - Métodos de guardado
    
    /// Guarda el contexto principal con manejo de errores
    func save() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                // CONFIGURABLE: Manejo de errores de guardado
                print("Error guardando contexto: \(error)")
                let nsError = error as NSError
                print("Error no controlado al guardar: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Guarda contexto de background
    func saveBackground(_ context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    // CONFIGURABLE: Manejo de errores en background
                    print("Error guardando contexto background: \(error)")
                }
            }
        }
    }
    
    // MARK: - Métodos de utilidad
    
    /// Elimina todos los datos (útil para testing o reset)
    func deleteAll() {
        let entities = container.managedObjectModel.entities
        
        for entity in entities {
            if let entityName = entity.name {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try viewContext.execute(deleteRequest)
                } catch {
                    print("Error eliminando entidad \(entityName): \(error)")
                }
            }
        }
        
        save()
    }
}
