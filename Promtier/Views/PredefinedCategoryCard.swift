//
//  PredefinedCategoryCard.swift
//  Promtier
//
//  VISTA: Tarjeta visual para categorías predefinidas con colores
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct PredefinedCategoryCard: View {
    let category: PredefinedCategory
    let promptCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono con fondo de color
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(category.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(promptCount) \(promptCount == 1 ? "prompt" : "prompts")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Indicador visual
            HStack(spacing: 4) {
                Circle()
                    .fill(category.color)
                    .frame(width: 6, height: 6)
                
                Text("\(promptCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(category.color)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(category.color.opacity(0.1))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(category.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        PredefinedCategoryCard(
            category: .iaModels,
            promptCount: 5
        )
        
        PredefinedCategoryCard(
            category: .code,
            promptCount: 12
        )
        
        PredefinedCategoryCard(
            category: .creative,
            promptCount: 0
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
