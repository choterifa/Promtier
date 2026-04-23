//
//  DiffView.swift
//  Promtier
//
//  VISTA: Comparación de textos con resaltado git-style (verde/rojo).
//

import SwiftUI

struct DiffView: View {
    @EnvironmentObject var preferences: PreferencesManager
    let text1: String
    let text2: String
    var title1: String = "Main Content"
    var title2: String = "Comparison"
    @Environment(\.dismiss) var dismiss
    
    @State private var diffLines: [LineDiff] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                    Text("diff_view_title".localized(for: preferences.language))
                        .font(.system(size: 16, weight: .bold))
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Diff Content
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left Column (Old/Removed)
                    diffColumn(title: title1, type: .removed, width: geo.size.width / 2)
                    
                    Divider()
                    
                    // Right Column (New/Added)
                    diffColumn(title: title2, type: .added, width: geo.size.width / 2)
                }
            }
        }
        .frame(width: max(600, preferences.windowWidth * 0.95), height: min(700, preferences.windowHeight * 0.90))
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            self.diffLines = DiffEngine.computeLineDiff(oldText: text1, newText: text2)
        }
    }
    
    @ViewBuilder
    private func diffColumn(title: String, type: DiffType, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.02))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(diffLines) { line in
                        if shouldShowLine(line, for: type) {
                            lineView(line)
                        } else if line.type == .unchanged {
                            lineView(line)
                        } else {
                            // Placeholder for alignment
                            Spacer()
                                .frame(height: 18)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .frame(width: width)
    }
    
    private func shouldShowLine(_ line: LineDiff, for type: DiffType) -> Bool {
        if type == .removed {
            return line.type == .removed || line.type == .unchanged
        } else {
            return line.type == .added || line.type == .unchanged
        }
    }
    
    @ViewBuilder
    private func lineView(_ line: LineDiff) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Line indicator (optional)
            Text(line.type == .added ? "+" : (line.type == .removed ? "-" : " "))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(lineColor(line.type).opacity(0.6))
                .frame(width: 12)
            
            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(line.type == .unchanged ? .primary.opacity(0.8) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(lineBackgroundColor(line.type))
    }
    
    private func lineColor(_ type: DiffType) -> Color {
        switch type {
        case .added: return .green
        case .removed: return .red
        case .unchanged: return .secondary
        }
    }
    
    private func lineBackgroundColor(_ type: DiffType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.15)
        case .removed: return Color.red.opacity(0.15)
        case .unchanged: return Color.clear
        }
    }
}
