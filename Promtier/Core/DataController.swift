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
    
    // CONFIGURABLE: Nombre del archivo de base de datos
    private static let modelName = "Promtier"
    
    // Container principal de Core Data
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: DataController.modelName)
        
        // CONFIGURABLE: Opciones de persistencia
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // CONFIGURABLE: Manejo de errores de carga
                print("Error cargando Core Data: \(error), \(error.userInfo)")
                fatalError("Error crítico al cargar base de datos: \(error)")
            }
        }
        
        // CONFIGURABLE: Contexto en background para operaciones pesadas
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // Contexto principal para la UI
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    // Contexto de background para operaciones pesadas
    var backgroundContext: NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    private init() {}
    
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
                fatalError("Error no controlado al guardar: \(nsError), \(nsError.userInfo)")
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
