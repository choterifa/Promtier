//
//  CategorySelectorButton.swift
//  Promtier
//
//  VISTA: Botón selector de categoría con colores para NewPromptView
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct CategorySelectorButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icono con color
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20, height: 20)
                
                // Título
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Indicador de selección
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? color.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 8) {
        CategorySelectorButton(
            title: "IA/Modelos",
            icon: "brain.head.profile",
            color: .blue,
            isSelected: false
        ) { }
        
        CategorySelectorButton(
            title: "Código",
            icon: "chevron.left.forwardslash.chevron.right",
            color: .green,
            isSelected: true
        ) { }
        
        CategorySelectorButton(
            title: "Creativo",
            icon: "paintbrush.pointed",
            color: .purple,
            isSelected: false
        ) { }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
