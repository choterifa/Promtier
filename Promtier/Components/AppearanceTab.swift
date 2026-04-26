import SwiftUI

struct AppearanceTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "appearance", icon: "display") {
                SettingsRow("language", subtitle: "language_subtitle") {
                    Picker("", selection: $preferences.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("appearance", subtitle: "appearance_subtitle") {
                    Picker("", selection: $preferences.appearance) {
                        Text("light".localized(for: preferences.language)).tag(AppAppearance.light)
                        Text("dark".localized(for: preferences.language)).tag(AppAppearance.dark)
                        Text("system".localized(for: preferences.language)).tag(AppAppearance.system)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("font_size", subtitle: "font_size_subtitle") {
                    Picker("", selection: $preferences.fontSize) {
                        Text("S").tag(FontSize.small)
                        Text("M").tag(FontSize.medium)
                        Text("L").tag(FontSize.large)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("preview_priority", subtitle: "preview_priority_subtitle") {
                    Picker("", selection: $preferences.previewImagesFirst) {
                        Text("images_first".localized(for: preferences.language)).tag(true)
                        Text("text_first".localized(for: preferences.language)).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("halo_effects", subtitle: "halo_effects_subtitle") {
                    Toggle("", isOn: $preferences.isHaloEffectEnabled)
                        .toggleStyle(.switch)
                }
                
                if preferences.isPremiumActive {
                    Divider().padding(.leading, 20)
                    
                    SettingsRow("visual_effects", subtitle: "visual_effects_subtitle") {
                        Toggle("", isOn: $preferences.visualEffectsEnabled)
                            .toggleStyle(.switch)
                    }
                }

                Divider().padding(.leading, 20)
                
                SettingsRow("auto_hide_sidebar_gallery", subtitle: "auto_hide_sidebar_gallery_subtitle") {
                    Toggle("", isOn: $preferences.autoHideSidebarInGallery)
                        .toggleStyle(.switch)
                }
            }
            
            SettingsSection(title: "window", icon: "macwindow.badge.plus") {
                SettingsRow("width", subtitle: "\(Int(preferences.previewWidth))px") {
                    Slider(value: $preferences.previewWidth, in: 500...900, step: 10, onEditingChanged: { editing in
                        preferences.isResizingVisible = editing
                        if !editing {
                            preferences.windowWidth = preferences.previewWidth
                        }
                    })
                    .onChange(of: preferences.previewWidth) { _, _ in
                        HapticService.shared.playStrong()
                    }
                    .frame(maxWidth: 150)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("height", subtitle: "\(Int(preferences.previewHeight))px") {
                    Slider(value: $preferences.previewHeight, in: 450...750, step: 10, onEditingChanged: { editing in
                        preferences.isResizingVisible = editing
                        if !editing {
                            preferences.windowHeight = preferences.previewHeight
                        }
                    })
                    .onChange(of: preferences.previewHeight) { _, _ in
                        HapticService.shared.playStrong()
                    }
                    .frame(maxWidth: 150)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("reset_size", subtitle: "reset_size_subtitle") {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            preferences.previewWidth  = 800
                            preferences.previewHeight = 570
                            preferences.windowWidth   = 800
                            preferences.windowHeight  = 570
                        }
                    }) {
                        Label("reset", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}