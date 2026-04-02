//
//  VersionHistoryView.swift
//  Promtier
//
//  VISTA: Historial de versiones de un prompt (Premium)
//  Inspirado en la referencia: lista izquierda + preview derecho + botón restaurar
//

import SwiftUI

struct VersionHistoryView: View {
    let snapshots: [PromptSnapshot]
    let currentContent: String
    let onRestore: (PromptSnapshot) -> Void

    @EnvironmentObject var preferences: PreferencesManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: PromptSnapshot? = nil

    private var selectedSnapshot: PromptSnapshot? { selected ?? snapshots.first }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .semibold))
                    Text("version_history".localized(for: preferences.language))
                        .font(.system(size: 17, weight: .bold))
                }
                Spacer()
                Text(String(format: "version_history_count".localized(for: preferences.language), snapshots.count))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()

            // Body: lista + preview
            HStack(spacing: 0) {
                // ─── Lista izquierda ───
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(snapshots) { snap in
                            SnapshotRow(
                                snapshot:  snap,
                                isSelected: selectedSnapshot?.id == snap.id
                            )
                            .onTapGesture { selected = snap }
                        }
                    }
                    .padding(12)
                }
                .frame(width: 230)
                .background(Color.primary.opacity(0.03))

                Divider()

                // ─── Preview derecho ───
                VStack(alignment: .leading, spacing: 0) {
                    if let snap = selectedSnapshot {
                        // Subheader
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)
                                Text(formattedDate(snap.timestamp))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { onRestore(snap) }) {
                                Label("restore_version".localized(for: preferences.language), systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue)
                                            .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.primary.opacity(0.025))

                        Divider()

                        // Contenido de la versión
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // 1. Contenido principal
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("main_prompt".localized(for: preferences.language))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(snap.content)
                                        .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                                        .foregroundColor(.primary.opacity(0.85))
                                }

                                // 2. Negative Prompt (si existe)
                                if let neg = snap.negativePrompt, !neg.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("negative_prompt".localized(for: preferences.language))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.red.opacity(0.6))
                                        Text(neg)
                                            .font(.system(size: 12 * preferences.fontSize.scale, design: .monospaced))
                                            .foregroundColor(.primary.opacity(0.75))
                                            .padding(10)
                                            .background(Color.red.opacity(0.05))
                                            .cornerRadius(6)
                                    }
                                }

                                // 3. Alternativas (si existen)
                                if !snap.alternatives.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("alternatives".localized(for: preferences.language))
                                        
                                        ForEach(Array(snap.alternatives.enumerated()), id: \.offset) { _, alt in
                                            Text(alt)
                                                .font(.system(size: 12 * preferences.fontSize.scale, design: .monospaced))
                                                .foregroundColor(.primary.opacity(0.75))
                                                .padding(10)
                                                .background(Color.blue.opacity(0.05))
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                        }
                    } else {
                        Spacer()
                        Text("select_version".localized(for: preferences.language))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 680, height: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let rel = formatter.localizedString(for: date, relativeTo: Date())

        let abs = DateFormatter()
        abs.dateFormat = "dd MMM yyyy, HH:mm"
        return "\(rel.capitalized) · \(abs.string(from: date))"
    }
}

// MARK: - Fila de snapshot

private struct SnapshotRow: View {
    let snapshot: PromptSnapshot
    let isSelected: Bool

    @EnvironmentObject var preferences: PreferencesManager

    private var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: snapshot.timestamp, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .blue : .secondary)
                Text(relativeDate)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .blue : .secondary)
                Spacer()
                Text(String(format: "char_count_short".localized(for: preferences.language), snapshot.content.count))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Text(snapshot.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(snapshot.content)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
