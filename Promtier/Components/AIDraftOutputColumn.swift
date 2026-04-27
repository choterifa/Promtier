import SwiftUI

struct AIDraftOutputColumn: View {
    @EnvironmentObject var manager: FloatingAIDraftManager
    @EnvironmentObject var preferences: PreferencesManager
    
    let onSave: () -> Void
    let onRefill: () -> Void
    let onRetry: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            contentArea
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.015))
    }
    
    private var headerRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.justify.left")
                    .font(.system(size: 9, weight: .bold))
                Text("RESULTADO")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
            }
            .foregroundColor(.purple)

            if !manager.responseText.isEmpty && !manager.isGenerating {
                HStack(spacing: 6) {
                    Button(action: onSave) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlainHoverButtonStyle(color: .blue, padding: (8, 6)))
                    .help("Guardar en galería")
                    .fixedSize()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            manager.isDiffActive.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: manager.isDiffActive ? "doc.plaintext.fill" : "rectangle.2.swap")
                            Text(manager.isDiffActive ? "Texto" : "Diff")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlainHoverButtonStyle(color: .purple, active: manager.isDiffActive, padding: (8, 6)))
                    .help(manager.isDiffActive ? "Ver resultado final" : "Comparar cambios")
                    .fixedSize()

                    Button(action: onRefill) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                            Text("Refill")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlainHoverButtonStyle(color: .blue, padding: (8, 6)))
                    .help("Mover resultado al editor original")
                    .fixedSize()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            manager.toggleFullSize()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: manager.isFullSize ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            Text(manager.isFullSize ? "Compacto" : "Zen")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(PlainHoverButtonStyle(color: .blue, active: manager.isFullSize, padding: (8, 6)))
                    .help(manager.isFullSize ? "Volver a vista dividida" : "Modo enfoque (Zen)")
                    .fixedSize()
                }
            }

            Spacer()
        }
        .frame(height: 28)
        .padding(.top, 20)
        .padding(.leading, 16).padding(.trailing, 24)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: .topLeading) {
            if manager.isGenerating {
                generatingOverlay
            } else if let error = manager.error {
                errorOverlay(error)
            } else if !manager.responseText.isEmpty {
                resultContent
            } else {
                emptyState
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
        .padding(.leading, 16).padding(.trailing, 24)
        .padding(.top, 10)
    }
    
    private var generatingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
            
            VStack(spacing: 4) {
                Text("IA trabajando...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Esto puede tardar unos segundos")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            Button(action: { manager.cancelExecution() }) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                    Text("Cancelar")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.red.opacity(0.8)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red.opacity(0.8))

            VStack(spacing: 8) {
                Text("Error de Conexión")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button(action: {
                if let lastReq = manager.history.last?.input {
                    onRetry(lastReq)
                } else {
                    manager.error = nil
                }
            }) {
                Text("Reintentar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.05)))
    }
    
    @ViewBuilder
    private var resultContent: some View {
        if manager.isDiffActive {
            ScrollView(showsIndicators: false) {
                DiffTextView(oldText: manager.content, newText: manager.responseText)
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary.opacity(0.02)))
        } else {
            ScrollView(showsIndicators: false) {
                Text(manager.responseText)
                    .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.15))
            Text("Los resultados de la IA\naparecerán aquí")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
