//
//  OnboardingView.swift
//  Promtier
//
//  VISTA: Guía inicial de bienvenida con diseño premium y explicativo
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var manager: FloatingOnboardingManager
    @EnvironmentObject var preferences: PreferencesManager
    private let totalSteps = 10
    
    var body: some View {
        ZStack {
            // Fondo Sólido y Premium
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header con Logo (Prompty) y Botón Omitir
                HStack {
                    Text("Prompty")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                        .tracking(-0.5)
                    
                    Spacer()
                    
                    Button(action: { manager.hide() }) {
                        Text("Omitir guía")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .opacity(manager.currentStep < totalSteps - 1 ? 1 : 0)
                }
                .padding(.horizontal, 40)
                .padding(.top, 35)
                
                // Contenido de los Pasos con transiciones suaves
                ZStack {
                    switch manager.currentStep {
                    case 0: welcomeStep
                    case 1: omniSearchStep
                    case 2: aiDraftStep
                    case 3: magicStep
                    case 4: spaceStep
                    case 5: galleryStep
                    case 6: dragDropStep
                    case 7: versionsStep
                    case 8: snippetsStep
                    case 9: readyStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(manager.currentStep) // Forzar animación al cambiar paso

                // Controles de Navegación
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { index in
                            Capsule()
                                .fill(manager.currentStep == index ? Color.blue : Color.primary.opacity(0.1))
                                .frame(width: manager.currentStep == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: manager.currentStep)
                        }
                    }
                    
                    Spacer()
                    
                    if manager.currentStep > 0 {
                        Button(action: { withAnimation { manager.currentStep -= 1 } }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.primary.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: { 
                        if manager.currentStep < totalSteps - 1 {
                            withAnimation { manager.currentStep += 1 }
                        } else {
                            manager.hide()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(manager.currentStep == totalSteps - 1 ? "Comenzar" : "Siguiente")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: manager.currentStep == totalSteps - 1 ? "checkmark.circle.fill" : "arrow.right")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                                .shadow(color: Color.blue.opacity(0.4), radius: 10, y: 5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .frame(width: 800, height: 600)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Pasos Individuales

    private var welcomeStep: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.05)).frame(width: 200, height: 200)
                Image(systemName: "brain.head.profile").font(.system(size: 90)).symbolRenderingMode(.hierarchical).foregroundStyle(.blue)
            }
            VStack(spacing: 12) {
                Text("Bienvenido a **Promtier**").font(.system(size: 42, weight: .bold))
                Text("Tu centro de comando para la era de la IA.").font(.system(size: 18)).foregroundColor(.secondary)
            }
        }
    }

    private var omniSearchStep: some View {
        VStack(spacing: 35) {
            VStack(spacing: 15) {
                HStack(spacing: 10) {
                    Text("Búsqueda Omni")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue))
                        .foregroundColor(.white)
                }
                Text("Accede a tus comandos desde cualquier app en segundos.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            ZStack {
                // Simulación visual del buscador con animación de escritura
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: 480, height: 80)
                    .overlay(
                        HStack {
                            Image(systemName: "magnifyingglass").font(.title2).foregroundColor(.blue)
                            Text(omniTypingText)
                                .font(.title3)
                                .foregroundColor(omniTypingText == "Empieza a escribir..." ? .secondary.opacity(0.5) : .primary)
                            
                            // Cursor parpadeante
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 2, height: 24)
                                .opacity(isCursorVisible ? 1 : 0)
                            
                            Spacer()
                            Text("⌘⇧Space").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.secondary).padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                        }
                        .padding(.horizontal, 25)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
            }
            
            VStack(alignment: .leading, spacing: 15) {
                onboardingFeatureRow(icon: "sparkles", text: "Sugerencias inteligentes basadas en lo que estás haciendo.")
                onboardingFeatureRow(icon: "keyboard", text: "Optimizado para ser 100% controlable por teclado.")
            }
            .padding(.horizontal, 60)
        }
        .onAppear {
            startOmniTyping()
        }
    }

    private var aiDraftStep: some View {
        VStack(spacing: 35) {
            VStack(spacing: 15) {
                Text("AI Quick Draft")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Crea, mejora y traduce tus prompts con potencia IA.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("BORRADOR").font(.system(size: 9, weight: .black)).opacity(0.5)
                    RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)).frame(width: 200, height: 140)
                        .overlay(
                            Text(draftTypingText)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        )
                }
                
                Image(systemName: "chevron.right").font(.title).foregroundColor(.blue.opacity(0.5))
                
                VStack(alignment: .leading) {
                    Text("IA").font(.system(size: 9, weight: .black)).foregroundColor(.purple)
                    RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.04)).frame(width: 200, height: 140)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.4), lineWidth: 2))
                        .overlay(
                            Text(aiTypingText)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(12)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        )
                }
            }
            
            Text("Crea y edita prompts al vuelo. Cero fricción, más diversión.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.blue.opacity(0.8))
                .padding(.top, 10)
        }
        .onAppear {
            startDraftAnimation()
        }
    }

    private var magicStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 15) {
                HStack(spacing: 8) {
                    Text("Magia y Autocompletado")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.purple))
                        .foregroundColor(.white)
                }
                
                Text("Deja que la IA complete los detalles y perfeccione tus ideas al instante.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            HStack(spacing: 40) {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .scaleEffect(magicPulse ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: magicPulse)
                    
                    Text("Magic (⌘J)").font(.caption).bold()
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("• Mejora la claridad al instante").font(.system(size: 15))
                    Text("• Traduce sobre la marcha").font(.system(size: 15))
                    Text("• Autocompletado inteligente").font(.system(size: 15))
                }
            }
            .padding(30).background(RoundedRectangle(cornerRadius: 20).fill(Color.primary.opacity(0.02)))
            .onAppear { magicPulse = true }
            
            Text("Configura tu **API Key** para desbloquear todo el potencial.")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.purple.opacity(0.8))
        }
    }

    private var spaceStep: some View {
        VStack(spacing: 35) {
            VStack(spacing: 15) {
                Text("Vista de Espacio").font(.system(size: 32, weight: .bold))
                Text("Inspecciona tus prompts al instante con la tecla espacio.").font(.system(size: 16)).foregroundColor(.secondary)
            }
            
            ZStack {
                // Fondo de Lista
                VStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.04))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedSpaceIndex == i ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                            )
                    }
                }
                .frame(width: 480)
                .opacity(0.4)
                
                // Popover de Space Animado
                if isShowingSpaceAnim {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(width: 380, height: 280)
                        .shadow(color: .black.opacity(0.2), radius: 30, y: 15)
                        .overlay(
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "doc.text.fill").foregroundColor(.blue)
                                    Text("Detalle del Prompt").font(.headline)
                                    Spacer()
                                    Image(systemName: "doc.on.doc").foregroundColor(.secondary)
                                }
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(height: 140)
                                    .overlay(
                                        Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
                                    )
                                
                                RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)).frame(height: 10)
                                RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)).frame(width: 200, height: 10)
                            }
                            .padding(25)
                        )
                        .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(height: 300)
            
            Text("Navega por tu lista y pulsa **Espacio** para ver la magia.")
                .font(.system(size: 14, weight: .bold)).foregroundColor(.blue)
        }
        .onAppear {
            startSpaceAnimation()
        }
        .onDisappear { 
            isShowingSpaceAnim = false 
        }
    }
    

    private var galleryStep: some View {
        VStack(spacing: 35) {
            VStack(spacing: 15) {
                Text("Galería de Prompts").font(.system(size: 32, weight: .bold))
                Text("Explora tus prompts visualmente para enfocarte en su resultado.").font(.system(size: 16)).foregroundColor(.secondary)
            }
            
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.01))
                
                // Contenedor infinito: 3 copias para asegurar cobertura total arriba y abajo
                VStack(spacing: 20) {
                    galleryCardSet
                    galleryCardSet
                    galleryCardSet
                }
                // Empezamos en -412 para mostrar el set central, y animamos hacia 0 para bajar
                // O de 0 a 412. El truco es que el punto inicial y final sean visualmente idénticos.
                .offset(y: isShowingGalleryAnim ? 0 : -412)
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isShowingGalleryAnim)
            }
            .frame(width: 500, height: 320)
            .clipped()
            .background(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            
            Text("Cambia entre **Lista** y **Cuadrícula** en la barra superior.")
                .font(.system(size: 14)).foregroundColor(.blue)
        }
        .onAppear { 
            // Pequeño delay para asegurar que el estado inicial se registre y empiece la animación
            DispatchQueue.main.async {
                isShowingGalleryAnim = true 
            }
        }
        .onDisappear { isShowingGalleryAnim = false }
    }
    
    private var galleryCardSet: some View {
        VStack(spacing: 20) {
            ForEach(0..<2) { row in
                HStack(spacing: 20) {
                    ForEach(0..<2) { col in
                        VStack(alignment: .leading, spacing: 0) {
                            // Imagen del prompt
                            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)).frame(height: 140)
                                .overlay(Image(systemName: "photo").foregroundColor(.secondary.opacity(0.4)))
                            
                            // Detalles del prompt
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.08)).frame(width: 120, height: 8)
                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.04)).frame(width: 80, height: 6)
                            }
                            .padding(12)
                        }
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
                    }
                }
            }
        }
    }
    

    private var dragDropStep: some View {
        VStack(spacing: 35) {
            VStack(spacing: 15) {
                Text("Arrastra y Suelta").font(.system(size: 32, weight: .bold))
                Text("Importa imágenes o exporta prompts con un solo movimiento.").font(.system(size: 16)).foregroundColor(.secondary)
            }
            
            ZStack {
                // Zona de soltado
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8]))
                    .frame(width: 400, height: 220)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.blue.opacity(0.01)))
                
                // Icono central
                VStack(spacing: 15) {
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.4))
                    Text("Suelta imágenes o prompts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                // Elementos animados secuenciales
                if isShowingDragAnim {
                    OnboardingDragItem(direction: .leftToCenter, delay: 0.5)
                    OnboardingDragItem(direction: .rightToCenter, delay: 2.8)
                }
            }
            .frame(height: 250)
            
            Text("Lleva tus prompts a otras apps o añade referencias visuales al instante.")
                .font(.system(size: 14)).foregroundColor(.blue)
        }
        .onAppear { 
            isShowingDragAnim = true 
        }
        .onDisappear { 
            isShowingDragAnim = false
        }
    }
    
    // Sub-vista para un item arrastrable
    private struct OnboardingDragItem: View {
        enum DragDirection {
            case leftToCenter
            case rightToCenter
        }
        
        let direction: DragDirection
        let delay: Double
        
        @State private var anim: Bool = false
        @State private var isShown: Bool = false
        
        var body: some View {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .frame(width: 140, height: 90)
                .shadow(color: .black.opacity(0.12), radius: 15, y: 10)
                .overlay(
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.1))
                            Image(systemName: direction == .leftToCenter ? "photo" : "doc.text.fill").foregroundColor(.blue).font(.system(size: 14))
                        }
                        .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.1)).frame(width: 50, height: 4)
                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.05)).frame(width: 30, height: 4)
                        }
                    }
                    .padding(12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .offset(x: anim ? 0 : (direction == .leftToCenter ? -200 : 200), y: anim ? 0 : -80)
                .rotationEffect(.degrees(anim ? 0 : (direction == .leftToCenter ? -10 : 10)))
                .scaleEffect(anim ? 0.9 : 1.1)
                .opacity(isShown ? (anim ? 0 : 1) : 0)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isShown = true
                        }
                        withAnimation(.easeInOut(duration: 2.2)) {
                            anim = true
                        }
                    }
                }
        }
    }

    private var versionsStep: some View {
        VStack(spacing: 35) {
            VStack(spacing: 15) {
                HStack(spacing: 10) {
                    Text("Historial de Versiones")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.purple))
                        .foregroundColor(.white)
                }
                Text("Viaja en el tiempo y recupera ediciones pasadas.").font(.system(size: 16)).foregroundColor(.secondary)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.02)).frame(width: 500, height: 260)
                    .overlay(
                        HStack(spacing: 0) {
                            // Simulamos la barra lateral de versiones
                            VStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.15)).frame(height: 50)
                                    .overlay(VStack(alignment: .leading, spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.3)).frame(width: 80, height: 6)
                                        RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.2)).frame(width: 120, height: 4)
                                    }.padding(.leading, 12), alignment: .leading)
                                ForEach(0..<2) { _ in
                                    RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)).frame(height: 50)
                                }
                                Spacer()
                            }
                            .frame(width: 150)
                            .padding(15)
                            
                            Divider()
                            
                            // Simulamos el botón restaurar
                            VStack(spacing: 20) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.05)).frame(width: 160, height: 12)
                                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.03)).frame(width: 120, height: 8)
                                    }
                                    Spacer()
                                    Text("Restaurar")
                                        .font(.system(size: 11, weight: .bold))
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.blue))
                                        .foregroundColor(.white)
                                }
                                
                                RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)).frame(height: 100)
                                Spacer()
                            }
                            .padding(20)
                        }
                    )
                    .scaleEffect(isShowingVersionsAnim ? 1.0 : 0.95)
                    .opacity(isShowingVersionsAnim ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isShowingVersionsAnim)
            }
            .frame(height: 260)
            
            Text("Nunca pierdas una gran idea. Cada cambio se guarda automáticamente.")
                .font(.system(size: 14)).foregroundColor(.secondary)
        }
        .onAppear { isShowingVersionsAnim = true }
        .onDisappear { isShowingVersionsAnim = false }
    }
    
    @State private var isShowingVersionsAnim = false

    private var snippetsStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 15) {
                Text("Snippets y Variables").font(.system(size: 32, weight: .bold))
                Text("Reutiliza bloques de texto con un solo comando.").font(.system(size: 16)).foregroundColor(.secondary)
            }
            
            HStack(spacing: 50) {
                VStack {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.05)).frame(width: 80, height: 80)
                        Text("/").font(.system(size: 40, weight: .black)).foregroundColor(.blue)
                    }
                    Text("Escribe '/'").font(.caption).bold()
                }
                
                VStack {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.05)).frame(width: 80, height: 80)
                        Image(systemName: "curlybraces").font(.system(size: 30)).foregroundColor(.blue)
                    }
                    Text("Variables {{}}").font(.caption).bold()
                }
            }
        }
    }
    
    private var readyStep: some View {
        VStack(spacing: 40) {
            ZStack {
                // Efecto Ripple (Ondas con relleno, más lentas)
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isVisibleReady ? 3.5 : 1.0)
                        .opacity(isVisibleReady ? 0.0 : 0.4)
                        .animation(.easeOut(duration: 3.5).repeatForever(autoreverses: false).delay(Double(i) * 1.0), value: isVisibleReady)
                }
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                    .scaleEffect(isVisibleReady ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isVisibleReady)
            }
            
            VStack(spacing: 15) {
                Text("¡Todo listo!")
                    .font(.system(size: 36, weight: .bold))
                
                Text("Bienvenido a **Prompty**. Ya puedes empezar a crear y potenciar tus **prompts**.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
        }
        .onAppear { isVisibleReady = true }
    }
    
    @State private var isVisibleReady = false
    
    private func onboardingFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.blue.opacity(0.1)))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.8))
            
            Spacer()
        }
    }
    
    // MARK: - Estados de Animación
    @State private var omniTypingText: String = ""
    @State private var draftTypingText: String = ""
    @State private var aiTypingText: String = ""
    @State private var selectedSpaceIndex: Int = 0
    @State private var isShowingSpaceAnim: Bool = false
    @State private var isShowingGalleryAnim: Bool = false
    @State private var isShowingDragAnim: Bool = false
    @State private var isCursorVisible: Bool = false
    @State private var magicPulse: Bool = false
    @State private var typingID = UUID()
    
    private func startOmniTyping() {
        let currentID = UUID()
        self.typingID = currentID
        
        let fullText = "Busca tu prompt favorito..."
        omniTypingText = ""
        
        // Cursor parpadeante (solo si el ID es actual)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if self.typingID != currentID {
                timer.invalidate()
                return
            }
            isCursorVisible.toggle()
        }
        
        // Animación de escritura
        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                if self.typingID == currentID {
                    omniTypingText.append(character)
                }
            }
        }
    }
    
    private func startDraftAnimation() {
        let currentID = UUID()
        self.typingID = currentID
        
        let draftText = "Crea un gato espacial"
        let aiText = "Cinematic shot of a fluffy cat in a detailed galaxy suit, nebula clouds, 8k resolution, photorealistic"
        
        draftTypingText = ""
        aiTypingText = ""
        
        // Fase 1: Escribir borrador
        for (index, char) in draftText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                if self.typingID == currentID {
                    draftTypingText.append(char)
                }
            }
        }
        
        // Fase 2: Escribir IA (con delay)
        let delay = Double(draftText.count) * 0.08 + 0.5
        for (index, char) in aiText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(index) * 0.04) {
                if self.typingID == currentID {
                    aiTypingText.append(char)
                }
            }
        }
    }
    
    private func startSpaceAnimation() {
        let currentID = UUID()
        self.typingID = currentID
        
        selectedSpaceIndex = 0
        isShowingSpaceAnim = false
        
        func runCycle(index: Int) {
            guard self.typingID == currentID else { return }
            
            // 1. Mostrar Preview
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedSpaceIndex = index
                isShowingSpaceAnim = true
            }
            
            // 2. Cerrar Preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard self.typingID == currentID else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    isShowingSpaceAnim = false
                }
                
                // 3. Mover al siguiente y repetir
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard self.typingID == currentID else { return }
                    runCycle(index: (index + 1) % 3)
                }
            }
        }
        
        // Empezar tras un pequeño delay inicial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            runCycle(index: 0)
        }
    }
}
