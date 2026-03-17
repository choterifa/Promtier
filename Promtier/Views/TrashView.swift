import SwiftUI

struct TrashView: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @State private var showingEmptyConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            if promptService.trashedPrompts.isEmpty {
                emptyState
            } else {
                trashList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
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
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    menuBarManager.activeViewState = .main
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Volver")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red.opacity(0.8))
                    Text("Papelera")
                        .font(.system(size: 15, weight: .bold))
                }
                Text("Los prompts se eliminan tras 7 días")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !promptService.trashedPrompts.isEmpty {
                Button(action: { showingEmptyConfirm = true }) {
                    Text("Vaciar")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)
            } else {
                // placeholder para mantener el centrado
                Color.clear.frame(width: 70, height: 28)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(.secondary.opacity(0.35))
            Text("La papelera está vacía")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Los prompts eliminados aparecerán aquí\ndurante 7 días antes de borrarse.")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Trash List
    
    private var trashList: some View {
        ScrollView(showsIndicators: false) {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            Color.primary.opacity(0.01)
        }
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
