import SwiftUI

struct SidebarNavView: View {
    @ObservedObject var appState: AppState
    @Binding var showSettings: Bool
    
    var body: some View {
        List(selection: Binding<NavigationTab?>(
            get: { appState.selectedTab },
            set: { if let val = $0 { appState.selectedTab = val } }
        )) {
            Section {
                ForEach(NavigationTab.allCases) { tab in
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 18)
                        
                        Text(tab.title(for: appState.currentLanguage))
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if tab == .collage {
                            Text(L10n.t(.comingSoon, lang: appState.currentLanguage))
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            bottomStatusBar
        }
    }
    
    private var bottomStatusBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .center, spacing: 6) {
                if !appState.images.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t(.allImagesCount(appState.images.count), lang: appState.currentLanguage))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("~\(appState.formatBytes(appState.totalEstimatedFileSize()))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                } else {
                    Text(L10n.t(.appName, lang: appState.currentLanguage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Subtle Settings Icon button (quick mouse click & cross-platform friendly)
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.t(.settings, lang: appState.currentLanguage))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
