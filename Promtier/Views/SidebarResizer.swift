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
    @State private var hasPushedCursor: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 16) // Hit area más amplia, contenida dentro de los límites de la vista
            .contentShape(Rectangle())
            .onHover { inside in
                isHovered = inside
                menuBarManager.setSidebarHovered(inside)
                
                if inside {
                    if !hasPushedCursor {
                        NSCursor.resizeLeftRight.push()
                        hasPushedCursor = true
                    }
                } else if !isDragging {
                    if hasPushedCursor {
                        NSCursor.pop()
                        hasPushedCursor = false
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartWidth = preferences.sidebarWidth
                            HapticService.shared.playLight()
                            
                            if !hasPushedCursor {
                                NSCursor.resizeLeftRight.push()
                                hasPushedCursor = true
                            }
                        }
                        
                        let proposed = dragStartWidth + value.translation.width
                        let newWidth = min(350, max(200, proposed))
                        
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
                            if hasPushedCursor {
                                NSCursor.pop()
                                hasPushedCursor = false
                            }
                            menuBarManager.setSidebarHovered(false)
                        }
                        HapticService.shared.playAlignment()
                    }
            )
    }
}
