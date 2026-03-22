//
//  OmniSearchView.swift
//  Promtier
//
//  VISTA: Buscador global tipo Spotlight
//

import SwiftUI
import AppKit

struct OmniSearchView: View {
    @EnvironmentObject var manager: OmniSearchManager
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var eventMonitor: Any?
    @FocusState private var isFocused: Bool
    
    private var filteredPrompts: [Prompt] {
        if query.isEmpty {
            return Array(promptService.prompts.prefix(8))
        } else {
            return promptService.prompts.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.content.localizedCaseInsensitiveContains(query) ||
                ($0.promptDescription?.localizedCaseInsensitiveContains(query) ?? false)
            }.prefix(10).map { $0 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barra de Búsqueda
            HStack(spacing: 15) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.blue)
                
                TextField("gt_search_prompts".localized(for: preferences.language), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .focused($isFocused)
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                    }
                    .onSubmit {
                        if !filteredPrompts.isEmpty {
                            copyAndClose(filteredPrompts[selectedIndex])
                        }
                    }
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Esc")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.05)))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            
            if !filteredPrompts.isEmpty {
                Divider().opacity(0.1)
                
                // Lista de Resultados
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                                OmniSearchRow(
                                    prompt: prompt,
                                    isSelected: selectedIndex == index,
                                    onTap: {
                                        copyAndClose(prompt)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 350)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            } else if !query.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("no_results".localized(for: preferences.language))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            }
            
            // Footer con atajos
            HStack {
                HStack(spacing: 12) {
                    Label {
                        Text("move_selection".localized(for: preferences.language))
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    
                    Label {
                        Text("copy_and_close".localized(for: preferences.language))
                    } icon: {
                        Image(systemName: "return")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                
                Spacer()
                
                Image("AppIconPlaceholder")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .opacity(0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            setupEventMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OmniSearchOpened"))) { _ in
            query = ""
            selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
    
    private func setupEventMonitor() {
        if eventMonitor != nil { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125: // Down
                if selectedIndex < filteredPrompts.count - 1 {
                    selectedIndex += 1
                    HapticService.shared.playLight()
                    return nil
                }
            case 126: // Up
                if selectedIndex > 0 {
                    selectedIndex -= 1
                    HapticService.shared.playLight()
                    return nil
                }
            case 53: // Esc
                manager.hide()
                return nil
            default:
                break
            }
            return event
        }
    }
    
    private func copyAndClose(_ prompt: Prompt) {
        ClipboardService.shared.copyToClipboard(prompt.content)
        HapticService.shared.playSuccess()
        if PreferencesManager.shared.soundEnabled {
            SoundService.shared.playMagicSound()
        }
        manager.hide()
    }
}

struct OmniSearchRow: View {
    let prompt: Prompt
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: prompt.icon ?? "doc.text.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : .blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if let desc = prompt.promptDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                } else {
                    Text(prompt.content)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
