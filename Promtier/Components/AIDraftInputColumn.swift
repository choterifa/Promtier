import SwiftUI

struct AIDraftInputColumn: View {
    @EnvironmentObject var manager: FloatingAIDraftManager
    @EnvironmentObject var preferences: PreferencesManager
    
    @FocusState.Binding var isDraftFocused: Bool
    let wordCount: Int
    
    @State private var localContent: String = ""
    @State private var textSyncTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "text.justify.left")
                        .font(.system(size: 9, weight: .bold))
                    Text("PROMPT ORIGINAL")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                }
                .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            .frame(height: 28)
            .padding(.top, 20)
            .padding(.leading, 24).padding(.trailing, 16)

            ZStack(alignment: .topLeading) {
                if localContent.isEmpty {
                    Text("Pega o escribe tu borrador aquí...")
                        .foregroundColor(.secondary.opacity(0.4))
                        .font(.system(size: 14 * preferences.fontSize.scale))
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $localContent)
                    .font(.system(size: 14 * preferences.fontSize.scale))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .disableNativeDrop()
                    .padding(12)
                    .focused($isDraftFocused)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
            .padding(.leading, 24).padding(.trailing, 16)
            .padding(.top, 10)

            HStack {
                HStack(spacing: 4) {
                    Text("\(localContent.count) carácteres")
                    Text("•")
                    Text("\(wordCount) palabras")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .frame(width: 370)
        .onAppear {
            localContent = manager.content
        }
        .onChange(of: manager.content) { _, new in
            if localContent != new { localContent = new }
        }
        .onChange(of: localContent) { _, new in
            if manager.content != new {
                textSyncTask?.cancel()
                textSyncTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    guard !Task.isCancelled else { return }
                    if manager.content != new { manager.content = new }
                }
            }
        }
    }
}
