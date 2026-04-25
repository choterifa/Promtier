//
//  SidebarResizer.swift
//  Promtier
//
//  Componente dedicado para el redimensionamiento del sidebar
//

import SwiftUI
import AppKit

struct SidebarResizer: View {
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @State private var isDragging: Bool = false
    @State private var dragStartWidth: CGFloat = 0
    @State private var isHovered: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 12) // Área de hit amplia (6px a cada lado)
            .contentShape(Rectangle())
            .offset(x: 6) // Centrar el hit area en el borde derecho
            .onHover { inside in
                isHovered = inside
                menuBarManager.setSidebarHovered(inside)
                
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else if !isDragging {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartWidth = preferences.sidebarWidth
                            HapticService.shared.playLight() // Feedback suave al enganchar
                            
                            // Si se arrastra súper rápido y no hubo hover, asegurar el cursor
                            if !isHovered {
                                NSCursor.resizeLeftRight.push()
                            }
                        }
                        
                        let proposed = dragStartWidth + value.translation.width
                        let newWidth = min(350, max(200, proposed)) // Límites fijos para evitar que se rompa
                        
                        // Feedback sutil si tocamos los topes
                        if (newWidth == 200 && preferences.sidebarWidth > 200) ||
                           (newWidth == 350 && preferences.sidebarWidth < 350) {
                            HapticService.shared.playImpact()
                        }
                        
                        preferences.sidebarWidth = newWidth
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartWidth = 0
                        
                        if !isHovered {
                            NSCursor.pop()
                            menuBarManager.setSidebarHovered(false)
                        }
                        HapticService.shared.playAlignment() // Feedback al soltar
                    }
            )
    }
}
