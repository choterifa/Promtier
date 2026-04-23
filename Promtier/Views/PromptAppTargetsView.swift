//
//  PromptAppTargetsView.swift
//  Promtier
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PromptAppTargetsView: View {
    @Binding var targetAppBundleIDs: [String]

    @State private var showingAppPicker = false
    @State private var showingSmartHelp = false

    let themeColor: Color
    let currentCategoryColor: Color
    let preferences: PreferencesManager
    let promptService: PromptService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PromtierSectionHeader(
                iconName: "sparkles",
                title: "smart_recommendation".localized(for: preferences.language).uppercased(),
                iconColor: themeColor,
                bottomPadding: 4
            ) {
                Button(action: { showingSmartHelp.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSmartHelp) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("smart_recommendation_help".localized(for: preferences.language))
                            .font(.headline)
                        Text("smart_recommendation_help_desc".localized(for: preferences.language))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(width: 250)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                if targetAppBundleIDs.isEmpty {
                    Text("no_apps_assigned".localized(for: preferences.language))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    // Usamos un HStack simple o una versión compatible de lo que hay en SharedAppPicker
                    // Dado que el FlowLayout actual en SharedAppPicker es muy limitado, 
                    // simplemente usamos un Wrap flexible nativo si fuera posible, pero para no romper:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(targetAppBundleIDs, id: \.self) { bundleID in
                                HStack(spacing: 6) {
                                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                        
                                        Text(FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: ""))
                                            .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                                    } else {
                                        Image(systemName: "app.dashed")
                                            .frame(width: 16, height: 16)
                                        Text(bundleID)
                                            .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                                    }
                                    
                                    Button(action: {
                                        withAnimation {
                                            targetAppBundleIDs.removeAll { $0 == bundleID }
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }

                Button(action: { showingAppPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("assign_app".localized(for: preferences.language))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeColor.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
                    AppPickerPopover(
                        runningApps: NSWorkspace.shared.getRelevantRunningApps(),
                        currentAppID: promptService.activeAppBundleID,
                        titleKey: "smart_recommendation",
                        onSelect: { bundleID in
                            if !targetAppBundleIDs.contains(bundleID) {
                                withAnimation {
                                    targetAppBundleIDs.append(bundleID)
                                }
                            }
                            showingAppPicker = false
                        },
                        onBrowse: {
                            showingAppPicker = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                browseApplications()
                            }
                        }
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                    .fill(preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.04) : Color.primary.opacity(0.01))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                            .stroke(preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.12) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private func browseApplications() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application, .aliasFile]
        panel.allowsMultipleSelection = true
        panel.message = "select_app_title".localized(for: preferences.language)
        panel.level = .modalPanel

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let bundleID = Bundle(url: url)?.bundleIdentifier {
                    if !targetAppBundleIDs.contains(bundleID) {
                        withAnimation {
                            targetAppBundleIDs.append(bundleID)
                        }
                    }
                } else {
                    let infoPath = url.appendingPathComponent("Contents/Info.plist")
                    if let infoDict = NSDictionary(contentsOf: infoPath),
                       let bundleID = infoDict["CFBundleIdentifier"] as? String,
                       !targetAppBundleIDs.contains(bundleID) {
                        withAnimation {
                            targetAppBundleIDs.append(bundleID)
                        }
                    }
                }
            }
        }
    }
}
