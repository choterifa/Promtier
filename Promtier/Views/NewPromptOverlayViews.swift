import SwiftUI

struct NewPromptBranchMessageOverlay: View {
    let message: String
    let language: AppLanguage

    var body: some View {
        VStack {
            Spacer()
            if message == "ai_thinking".localized(for: language) {
                AnimatedThinkingText(baseText: message.replacingOccurrences(of: "...", with: ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.purple)
                            .shadow(radius: 10)
                    )
                    .padding(.bottom, 40)
            } else {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(message.hasPrefix("❌") ? Color.red : Color.purple)
                            .shadow(radius: 10)
                    )
                    .padding(.bottom, 40)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(400)
    }
}

struct NewPromptMagicOptionsOverlay: View {
    @Binding var showingMagicOptions: Bool
    @Binding var magicTarget: MagicTarget
    @Binding var magicCommand: String

    let executeAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(showingMagicOptions ? 0.3 : 0.0)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showingMagicOptions = false } }

            if showingMagicOptions {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                        Text("Modificar con IA")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showingMagicOptions = false } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("¿Qué deseas modificar?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(MagicTarget.allCases) { target in
                                Button(action: { magicTarget = target }) {
                                    Text(target.rawValue)
                                        .font(.system(size: 13, weight: magicTarget == target ? .semibold : .regular))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(magicTarget == target ? Color.blue : Color.primary.opacity(0.05))
                                        )
                                        .foregroundColor(magicTarget == target ? .white : .primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(magicTarget == target ? Color.blue : Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if magicTarget == .content {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instrucciones")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField("Ej: Haz el texto más amigable...", text: $magicCommand, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                .lineLimit(3...6)
                                .onSubmit { executeAction() }
                                .onAppear {
                                    magicCommand = ""
                                }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Se generará automáticamente un nuevo texto para \(magicTarget.rawValue) basado en el contenido existente.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Modificar") { executeAction() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(magicTarget == .content && magicCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(24)
                .frame(width: 450)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 40, x: 0, y: 20)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(showingMagicOptions)
        .zIndex(202)
    }
}
