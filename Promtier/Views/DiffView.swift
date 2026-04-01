import SwiftUI

struct DiffView: View {
    let text1: String
    let text2: String
    var title1: String = "Main Content"
    var title2: String = "Comparison"
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Diff View")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Text(title1)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ScrollView {
                        Text(text1)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.03))
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text(title2)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ScrollView {
                        Text(text2)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.03))
            }
        }
        .frame(width: max(400, PreferencesManager.shared.windowWidth * 0.90), height: min(600, PreferencesManager.shared.windowHeight * 0.85))
    }
}
