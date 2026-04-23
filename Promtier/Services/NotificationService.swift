import Foundation
import UserNotifications
import AppKit

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("❌ Error solicitando permisos de notificación: \(error.localizedDescription)")
            }
        }
    }
    
    func sendAIDraftNotification(title: String, body: String) {
        // Solo enviar si la ventana no es la frontal o si el usuario quiere ser notificado
        // Para esta tarea, asumimos que el usuario la quiere siempre que termine la IA
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Añadir una acción para abrir la app (opcional, por defecto al hacer click abre)
        
        let request = UNNotificationRequest(
            identifier: "AIDraftReady-\(UUID().uuidString)",
            content: content,
            trigger: nil // Inmediato
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Mostrar la notificación incluso si la app está en primer plano
        completionHandler([.banner, .sound])
    }
}
