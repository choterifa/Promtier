import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BehaviorTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var showingAppPicker = false
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "interaction", icon: "hand.tap.fill") {
                SettingsRow("include_subcategory_prompts", subtitle: "include_subcategory_prompts_subtitle", icon: "rectangle.stack.fill", iconColor: .blue) {
                    Toggle("", isOn: $preferences.includeSubcategoryPrompts)
                        .toggleStyle(.switch)
                }

                Divider().padding(.leading, 20)

                SettingsRow("sounds", subtitle: "sounds_subtitle", icon: "speaker.wave.2.fill", iconColor: .blue) {
                    Toggle("", isOn: $preferences.soundEnabled)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)

                SettingsRow("trackpad_carousel", subtitle: "trackpad_carousel_subtitle", icon: "hand.draw.fill", iconColor: .blue) {
                    Toggle("", isOn: $preferences.enableTrackpadCarousel)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("ghost_tips", subtitle: "ghost_tips_subtitle", icon: "sparkles", iconColor: .blue) {
                    Toggle("", isOn: $preferences.ghostTipsEnabled)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)

                SettingsRow("disable_image_animations", subtitle: "disable_image_animations_subtitle", icon: "video.slash.fill", iconColor: .purple) {
                    Toggle("", isOn: $preferences.disableImageAnimations)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("show_advanced_fields", subtitle: "show_advanced_fields_subtitle", icon: "slider.horizontal.3", iconColor: .blue) {
                    Toggle("", isOn: $preferences.showAdvancedFields)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("close_on_copy", subtitle: "close_on_copy_subtitle", icon: "xmark.square.fill", iconColor: .red) {
                    Toggle("", isOn: $preferences.closeOnCopy)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("clipboard_suggestions", subtitle: "clipboard_suggestions_subtitle", icon: "doc.on.clipboard.fill", iconColor: .blue) {
                    Toggle("", isOn: $preferences.clipboardSuggestions)
                        .toggleStyle(.switch)
                }
                
                    
                    // Lista de aplicaciones personalizadas
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("custom_apps".localized(for: preferences.language))
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Button(action: { showingAppPicker = true }) {
                                Label("add_app".localized(for: preferences.language), systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .popover(isPresented: $showingAppPicker, arrowEdge: .top) {
                                AppPickerPopover(
                                    runningApps: NSWorkspace.shared.getRelevantRunningApps(),
                                    currentAppID: nil,
                                    titleKey: "custom_apps",
                                    onSelect: { bundleID in
                                        _ = preferences.addAppToWhitelist(bundleID: bundleID)
                                        showingAppPicker = false
                                    },
                                    onBrowse: {
                                        showingAppPicker = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            selectApplication()
                                        }
                                    }
                                )
                            }
                        }
                        
                        if !preferences.customAllowedAppBundleIDs.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(Array(preferences.customAllowedAppBundleIDs).sorted(), id: \.self) { bundleID in
                                    HStack {
                                        let appName = getAppName(from: bundleID)
                                        Image(systemName: "app.badge.fill")
                                            .foregroundColor(.blue.opacity(0.7))
                                        Text(appName)
                                            .font(.system(size: 11, design: .monospaced))
                                        Spacer()
                                        Button(action: { preferences.removeAppFromWhitelist(bundleID: bundleID) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.03))
                                    .cornerRadius(8)
                                }
                            }
                        } else {
                            Text("manage_allowed_apps".localized(for: preferences.language))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    .padding(.leading, 40)
                    .padding(.top, 4)
            }
            
            SettingsSection(title: "haptic_feedback", icon: "hand.tap.fill") {
                SettingsRow("haptic_feedback", subtitle: "haptic_feedback_subtitle") {
                    Toggle("", isOn: $preferences.hapticFeedbackEnabled)
                        .toggleStyle(.switch)
                }
            }
            
            SettingsSection(title: "shortcuts_gestures", icon: "keyboard") {
                SettingsRow("double_tap_right_command", subtitle: "double_tap_right_command_subtitle", icon: "bolt.fill", iconColor: .orange) {
                    Toggle("", isOn: $preferences.doubleRightCommandForMagicSave)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("double_tap_right_option", subtitle: "double_tap_right_option_subtitle", icon: "sparkles", iconColor: .blue) {
                    Toggle("", isOn: $preferences.doubleRightOptionForAIDraft)
                        .toggleStyle(.switch)
                }
            }

            SettingsSection(title: "system", icon: "macwindow") {
                SettingsRow("launch_at_login", subtitle: "launch_at_login_subtitle") {
                    Toggle("", isOn: $preferences.launchAtLogin)
                        .toggleStyle(.switch)
                }
            }
            
            SettingsSection(title: "premium", icon: "crown.fill") {
                SettingsRow("activate_premium", subtitle: "activate_premium_subtitle", icon: "sparkles", iconColor: .purple) {
                    Toggle("", isOn: $preferences.isPremiumActive)
                        .toggleStyle(.switch)
                }
            }

            SettingsSection(title: "permissions", icon: "lock.shield.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsRow("accessibility", subtitle: "accessibility_subtitle", icon: "hand.tap.fill", iconColor: ShortcutManager.shared.isAccessibilityGranted ? .green : .red) {
                        HStack(spacing: 8) {
                            if ShortcutManager.shared.isAccessibilityGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("granted")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            } else {
                                Button(action: {
                                    ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: true)
                                }) {
                                    Text("grant_access")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    if !ShortcutManager.shared.isAccessibilityGranted {
                        Text("accessibility_description")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    private func getAppName(from bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.message = "add_app".localized(for: preferences.language)
        panel.prompt = "add".localized(for: preferences.language)
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.application]

        if panel.runModal() == .OK, let url = panel.url {
            if preferences.addAppToWhitelist(at: url) {
                HapticService.shared.playLight()
            }
        }
    }
}