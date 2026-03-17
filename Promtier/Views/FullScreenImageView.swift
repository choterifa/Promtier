import SwiftUI

struct FullScreenImageView: View {
    let imageData: Data
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding()
            }
            .background(Color.black.opacity(0.4))
            
            Spacer()
            
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(20)
            }
            
            Spacer()
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color.black)
    }
}
