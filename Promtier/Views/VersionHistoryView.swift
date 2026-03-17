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
                    Text("Historial de Versiones")
                        .font(.system(size: 17, weight: .bold))
                }
                Spacer()
                Text("\(snapshots.count) versiones guardadas")
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
                                Label("Restaurar", systemImage: "arrow.counterclockwise")
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
                            Text(snap.content)
                                .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                        }
                    } else {
                        Spacer()
                        Text("Selecciona una versión")
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
                Text("\(snapshot.content.count) car.")
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
