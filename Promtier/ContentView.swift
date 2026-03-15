//
//  ContentView.swift
//  Promtier
//
//  VISTA MINIMAL: Contenedor principal para la app
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "text.bubble")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Promtier - Gestor de Prompts")
                .font(.title2)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
