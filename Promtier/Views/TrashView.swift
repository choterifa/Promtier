import SwiftUI

struct TrashView: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @State private var showingEmptyConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header for the Tab Content area (optional, as PreferencesView already has a header)
            // But we need the 'Empty' button somewhere.
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Los prompts se eliminan tras 7 días")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !promptService.trashedPrompts.isEmpty {
                    Button(action: { showingEmptyConfirm = true }) {
                        Label("Vaciar papelera", systemImage: "trash.slash.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)

            if promptService.trashedPrompts.isEmpty {
                emptyState
                    .padding(.vertical, 60)
            } else {
                VStack(spacing: 8) {
                    ForEach(promptService.trashedPrompts) { prompt in
                        TrashItemRow(prompt: prompt) {
                            withAnimation(.spring(response: 0.3)) {
                                _ = promptService.restorePrompt(prompt)
                            }
                            HapticService.shared.playLight()
                        } onDelete: {
                            withAnimation(.spring(response: 0.3)) {
                                _ = promptService.permanentlyDeletePrompt(prompt)
                            }
                            HapticService.shared.playStrong()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Vaciar papelera", isPresented: $showingEmptyConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Vaciar", role: .destructive) {
                withAnimation { promptService.emptyTrash() }
                HapticService.shared.playStrong()
            }
        } message: {
            Text("Esto eliminará permanentemente \(promptService.trashedPrompts.count) prompt(s). Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.secondary.opacity(0.35))
            Text("La papelera está vacía")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Los prompts eliminados aparecerán aquí\ndurante 7 días antes de borrarse.")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trash Item Row

struct TrashItemRow: View {
    let prompt: Prompt
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    private var daysRemaining: Int {
        guard let d = prompt.deletedAt else { return 7 }
        let elapsed = Int(Date().timeIntervalSince(d) / 86400)
        return max(0, 7 - elapsed)
    }
    
    private var timeLabel: String {
        daysRemaining == 0 ? "Hoy" : "\(daysRemaining)d restantes"
    }
    
    private var urgencyColor: Color {
        daysRemaining <= 1 ? .red : (daysRemaining <= 3 ? .orange : .secondary)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.08))
                    .frame(width: 34, height: 34)
                Image(systemName: prompt.icon ?? "doc.text.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.6))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.title)
                    .font(.system(size: 14 * preferences.fontSize.scale, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.75))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let folder = prompt.folder {
                        Text(folder)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.07)))
                    }
                    
                    // Countdown
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(timeLabel)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(urgencyColor)
                }
            }
            
            Spacer()
            
            // Actions (visible on hover)
            HStack(spacing: 8) {
                Button(action: onRestore) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Restaurar")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
