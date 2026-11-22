import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: Hashable {
        case general
        case export
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Tab Selector
            HStack {
                Picker("", selection: $selectedTab) {
                    Label(L10n.t(.generalSettings, lang: appState.currentLanguage), systemImage: "gearshape")
                        .tag(SettingsTab.general)
                    Label(L10n.t(.exportSettingsTab, lang: appState.currentLanguage), systemImage: "arrow.up.forward.square")
                        .tag(SettingsTab.export)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                
                Spacer()
                
                Button(L10n.t(.done, lang: appState.currentLanguage)) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .background {
                    Button("") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .opacity(0)
                        .allowsHitTesting(false)
                }
            }
            .padding()
            
            Divider()
            
            // Tab Contents
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == .general {
                        generalTabContent
                    } else {
                        exportTabContent
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 420)
    }
    
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t(.language, lang: appState.currentLanguage))
                                .font(.headline)
                            Text(appState.currentLanguage == .zh ? "选择软件界面使用的语言" : "Choose the language for the app interface")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $appState.currentLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                }
                .padding(8)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t(.appName, lang: appState.currentLanguage))
                                .font(.headline)
                            Text("Version 1.0 (Build 2026.11)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(8)
            }
            
            Spacer()
        }
    }
    
    private var exportTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t(.defaultExportQuality, lang: appState.currentLanguage))
                .font(.headline)
            
            VStack(spacing: 10) {
                ForEach(ExportQuality.allCases) { quality in
                    qualityPresetCard(quality: quality)
                }
            }
            
            Spacer()
        }
    }
    
    private func qualityPresetCard(quality: ExportQuality) -> some View {
        let isSelected = appState.defaultExportQuality == quality
        
        return Button {
            appState.defaultExportQuality = quality
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(quality.title(for: appState.currentLanguage))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if quality == .high {
                            Text(appState.currentLanguage == .zh ? "推荐交付" : "Recommended")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(quality.subtitle(for: appState.currentLanguage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
