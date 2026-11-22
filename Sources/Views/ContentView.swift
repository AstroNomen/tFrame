import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var isTargeted = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationSplitView {
            SidebarNavView(appState: appState, showSettings: $showSettings)
                .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } content: {
            if appState.selectedTab == .frameWatermark {
                MainWorkArea(appState: appState, isTargeted: $isTargeted, onAddPhotos: openImagePicker)
                    .navigationSplitViewColumnWidth(min: 450, ideal: 650, max: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                exportSelected()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                    Text(L10n.t(.exportSelected, lang: appState.currentLanguage))
                                }
                            }
                            .disabled(appState.selectedImageID == nil)
                            .help(L10n.t(.exportSelected, lang: appState.currentLanguage))
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                exportAll()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up.on.square")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                    Text(L10n.t(.exportAll, lang: appState.currentLanguage))
                                }
                            }
                            .disabled(appState.images.isEmpty)
                            .help(L10n.t(.exportAll, lang: appState.currentLanguage))
                        }
                    }
            } else {
                CollagePlaceholderView(appState: appState)
                    .navigationSplitViewColumnWidth(min: 450, ideal: 650, max: .infinity)
            }
        } detail: {
            SettingsInspector(appState: appState)
                .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 320)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            loadProviders(providers)
            return true
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(
            WindowAccessor { window in
                window.titlebarSeparatorStyle = .none
            }
        )
    }
    
    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.prompt = L10n.t(.selectPrompt, lang: appState.currentLanguage)
        panel.title = L10n.t(.addPhotos, lang: appState.currentLanguage)
        
        if panel.runModal() == .OK {
            appState.addImages(from: panel.urls)
        }
    }
    
    private func loadProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    if let data = data {
                        var targetURL: URL?
                        if let url = URL(dataRepresentation: data, relativeTo: nil) {
                            targetURL = url
                        } else if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                                  let url = URL(string: str) {
                            targetURL = url
                        }
                        if let url = targetURL {
                            DispatchQueue.main.async {
                                appState.addImages(from: [url])
                            }
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { reading, _ in
                    if let nsURL = reading as? NSURL {
                        DispatchQueue.main.async {
                            appState.addImages(from: [nsURL as URL])
                        }
                    }
                }
            }
        }
    }
    
    private func exportSelected() {
        guard let index = appState.selectedImageIndex, index < appState.images.count else { return }
        let processable = appState.images[index]
        let quality = appState.effectiveQuality(for: processable)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.jpeg, .png]
            let originalName = processable.originalURL.deletingPathExtension().lastPathComponent
            panel.nameFieldStringValue = "\(originalName)_tFrame.jpg"
            panel.title = L10n.t(.exportPhotoTitle, lang: appState.currentLanguage)
            panel.message = L10n.t(.exportPhotoMessage, lang: appState.currentLanguage)
            panel.prompt = L10n.t(.exportSelected, lang: appState.currentLanguage)
            
            if panel.runModal() == .OK, let url = panel.url {
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                if let cgImage = await ImageProcessor.shared.processCGImage(image: processable, state: appState) {
                    save(cgImage: cgImage, sourceURL: processable.originalURL, quality: quality, to: url)
                }
            }
        }
    }
    
    private func exportAll() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.canChooseFiles = false
            panel.title = L10n.t(.exportFolderTitle, lang: appState.currentLanguage)
            panel.prompt = L10n.t(.exportFolderPrompt, lang: appState.currentLanguage)
            
            if panel.runModal() == .OK, let folderURL = panel.url {
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                for processable in appState.images {
                    await Task.yield() // Keep UI responsive during batch export
                    let quality = appState.effectiveQuality(for: processable)
                    guard let cgImage = await ImageProcessor.shared.processCGImage(image: processable, state: appState) else { continue }
                    
                    let originalName = processable.originalURL.deletingPathExtension().lastPathComponent
                    let fileURL = folderURL.appendingPathComponent("\(originalName)_tFrame.jpg")
                    save(cgImage: cgImage, sourceURL: processable.originalURL, quality: quality, to: fileURL)
                }
            }
        }
    }
    
    private func save(cgImage: CGImage, sourceURL: URL?, quality: ExportQuality, to url: URL) {
        let isPNG = url.pathExtension.lowercased() == "png"
        let utType = isPNG ? UTType.png.identifier as CFString : UTType.jpeg.identifier as CFString
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, utType, 1, nil) else { return }
        
        var metadata: [CFString: Any] = [:]
        
        if let sourceURL = sourceURL, let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) {
            if let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                metadata = sourceProperties
            }
        }
        
        metadata[kCGImagePropertyPixelWidth] = cgImage.width
        metadata[kCGImagePropertyPixelHeight] = cgImage.height
        metadata[kCGImagePropertyOrientation] = 1
        
        if !isPNG {
            metadata[kCGImageDestinationLossyCompressionQuality] = quality.compressionFactor
        }
        
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        CGImageDestinationFinalize(destination)
    }
}

// MARK: - Main Work Area (Preview + Bottom Info Bar + Filmstrip)

struct MainWorkArea: View {
    @ObservedObject var appState: AppState
    @Binding var isTargeted: Bool
    var onAddPhotos: () -> Void
    
    @State private var previewImage: NSImage?
    
    private var previewTrigger: Int {
        var hasher = Hasher()
        hasher.combine(appState.previewVersion)
        hasher.combine(appState.selectedImageID)
        hasher.combine(appState.frameWidthPercentage)
        hasher.combine(appState.themeColor)
        hasher.combine(appState.defaultWatermarkPosition)
        hasher.combine(appState.inPhotoWatermarkOpacity)
        hasher.combine(appState.frameWatermarkOpacity)
        hasher.combine(appState.inPhotoWatermarkScale)
        hasher.combine(appState.frameWatermarkScale)
        hasher.combine(appState.defaultFrameStyle)
        hasher.combine(appState.defaultExportQuality)
        hasher.combine(appState.customInPhotoLightURL)
        hasher.combine(appState.customInPhotoDarkURL)
        hasher.combine(appState.customFrameLightURL)
        hasher.combine(appState.customFrameDarkURL)
        
        if let idx = appState.selectedImageIndex, idx < appState.images.count {
            let img = appState.images[idx]
            hasher.combine(img.customWatermarkPosition)
            hasher.combine(img.customFrameStyle)
            hasher.combine(img.customThemeColor)
            hasher.combine(img.customInPhotoWatermarkTheme)
            hasher.combine(img.customFrameWatermarkTheme)
            hasher.combine(img.customInPhotoWatermarkScale)
            hasher.combine(img.customFrameWatermarkScale)
            hasher.combine(img.customInPhotoWatermarkOpacity)
            hasher.combine(img.customExportQuality)
        }
        return hasher.finalize()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Clean Preview Area
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                if isTargeted {
                    Color.accentColor.opacity(0.12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                        )
                }
                
                if let _ = appState.selectedImageIndex {
                    if let preview = previewImage {
                        Image(nsImage: preview)
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressView(L10n.t(.processingPreview, lang: appState.currentLanguage))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text(L10n.t(.dragDropHint, lang: appState.currentLanguage))
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Button(action: onAddPhotos) {
                            Label(L10n.t(.addPhotos, lang: appState.currentLanguage), systemImage: "plus")
                        }
                        .controlSize(.regular)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Status & Dimensions Bar (Unified background matching preview workspace)
            if let selected = appState.selectedImage {
                let (dimW, dimH) = appState.effectiveDimensions(for: selected)
                let fileSize = appState.estimatedFileSize(for: selected)
                let totalSize = appState.totalEstimatedFileSize()
                let quality = appState.effectiveQuality(for: selected)
                
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: "aspectratio")
                                .foregroundColor(.secondary)
                            Text("\(dimW) × \(dimH) px")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                        }
                        
                        Divider()
                            .frame(height: 12)
                        
                        HStack(spacing: 5) {
                            Image(systemName: "doc.badge.arrow.up")
                                .foregroundColor(.secondary)
                            Text("\(L10n.t(.estimatedSize, lang: appState.currentLanguage)): ~\(appState.formatBytes(fileSize))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("(\(quality.title(for: appState.currentLanguage)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if appState.images.count > 1 {
                            HStack(spacing: 5) {
                                Image(systemName: "square.stack.3d.up")
                                    .foregroundColor(.secondary)
                                Text("\(L10n.t(.totalEstimatedSize, lang: appState.currentLanguage)): ~\(appState.formatBytes(totalSize))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
            
            // Bottom Horizontal Filmstrip Carousel
            FilmstripView(appState: appState, onAddPhotos: onAddPhotos)
        }
        .task(id: previewTrigger) {
            guard let index = appState.selectedImageIndex, index < appState.images.count else {
                previewImage = nil
                return
            }
            let processable = appState.images[index]
            let img = await ImageProcessor.shared.process(image: processable, state: appState)
            
            guard !Task.isCancelled else { return }
            self.previewImage = img
        }
    }
}

// MARK: - Collage Placeholder View

struct CollagePlaceholderView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.7))
            
            Text(L10n.t(.collagePlaceholderTitle, lang: appState.currentLanguage))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(L10n.t(.collagePlaceholderSubtitle, lang: appState.currentLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            
            Button {
                appState.selectedTab = .frameWatermark
            } label: {
                Text(L10n.t(.tabFrameWatermark, lang: appState.currentLanguage))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Settings Inspector (Decoupled Scope: Current vs Global)

struct SettingsInspector: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Inspector Scope Switcher (This Photo vs Global Defaults)
            Picker("", selection: $appState.inspectorScope) {
                ForEach(InspectorScope.allCases) { scope in
                    Text(scope.title(for: appState.currentLanguage)).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Scope Contents
            ScrollView {
                if appState.inspectorScope == .current {
                    currentPhotoInspector
                } else {
                    globalDefaultsInspector
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Current Photo Inspector
    
    private var currentPhotoInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let selectedIndex = appState.selectedImageIndex,
               selectedIndex < appState.images.count {
                let processable = appState.images[selectedIndex]
                
                // Header with File Name & Reset Button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(processable.originalURL.lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        if processable.hasCustomOverrides {
                            Text(L10n.t(.customizedBadge, lang: appState.currentLanguage))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        } else {
                            Text(L10n.t(.useGlobalDefault, lang: appState.currentLanguage))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if processable.hasCustomOverrides {
                        Button(L10n.t(.resetToDefaults, lang: appState.currentLanguage)) {
                            appState.resetCurrentPhotoOverrides()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                
                // Metric Card: Dimensions & Size
                let (dimW, dimH) = appState.effectiveDimensions(for: processable)
                let fileSize = appState.estimatedFileSize(for: processable)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t(.estimatedDimensions, lang: appState.currentLanguage))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(dimW) × \(dimH) px")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.t(.estimatedSize, lang: appState.currentLanguage))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("~\(appState.formatBytes(fileSize))")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 14)
                
                Divider()
                    .padding(.horizontal, 14)
                
                // Current Photo Controls Form
                VStack(alignment: .leading, spacing: 14) {
                    // Export Quality
                    let curQ = appState.effectiveQuality(for: processable)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.t(.exportQualitySection, lang: appState.currentLanguage))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Picker("", selection: Binding<ExportQuality?>(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return nil }
                                    return appState.images[selectedIndex].customExportQuality 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    appState.images[selectedIndex].customExportQuality = $0
                                    appState.bumpPreview()
                                }
                            )) {
                                Text("\(L10n.t(.useGlobalDefault, lang: appState.currentLanguage)) (\(appState.defaultExportQuality.title(for: appState.currentLanguage)))")
                                    .tag(ExportQuality?.none)
                                ForEach(ExportQuality.allCases) { q in
                                    Text(q.title(for: appState.currentLanguage)).tag(ExportQuality?.some(q))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)
                        }
                        
                        Text(curQ.subtitle(for: appState.currentLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(curQ.subtitle(for: appState.currentLanguage))
                    }
                    .padding(.horizontal, 14)
                    
                    Divider()
                        .padding(.horizontal, 14)
                    
                    // Frame Style & Color
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t(.frameSettings, lang: appState.currentLanguage))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text(L10n.t(.themeColor, lang: appState.currentLanguage))
                            Spacer()
                            Picker("", selection: Binding<ThemeColor?>(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return nil }
                                    return appState.images[selectedIndex].customThemeColor 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    appState.images[selectedIndex].customThemeColor = $0
                                    appState.bumpPreview()
                                }
                            )) {
                                Text("\(L10n.t(.useGlobalDefault, lang: appState.currentLanguage)) (\(appState.themeColor.title(for: appState.currentLanguage)))")
                                    .tag(ThemeColor?.none)
                                ForEach(ThemeColor.allCases) { color in
                                    Text(color.title(for: appState.currentLanguage)).tag(ThemeColor?.some(color))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)
                        }
                        
                        HStack {
                            Text(L10n.t(.defaultStyle, lang: appState.currentLanguage))
                            Spacer()
                            Picker("", selection: Binding<FrameStyle?>(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return nil }
                                    return appState.images[selectedIndex].customFrameStyle 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    appState.images[selectedIndex].customFrameStyle = $0
                                    appState.bumpPreview()
                                }
                            )) {
                                Text("\(L10n.t(.useGlobalDefault, lang: appState.currentLanguage)) (\(appState.defaultFrameStyle.title(for: appState.currentLanguage)))")
                                    .tag(FrameStyle?.none)
                                ForEach(FrameStyle.allCases) { style in
                                    Text(style.title(for: appState.currentLanguage)).tag(FrameStyle?.some(style))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)
                        }
                    }
                    .padding(.horizontal, 14)
                    
                    Divider()
                        .padding(.horizontal, 14)
                    
                    // Watermark Overrides
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t(.watermarkSettings, lang: appState.currentLanguage))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text(L10n.t(.defaultPosition, lang: appState.currentLanguage))
                            Spacer()
                            Picker("", selection: Binding<WatermarkPosition?>(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return nil }
                                    return appState.images[selectedIndex].customWatermarkPosition 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    appState.images[selectedIndex].customWatermarkPosition = $0
                                    appState.bumpPreview()
                                }
                            )) {
                                Text("\(L10n.t(.useGlobalDefault, lang: appState.currentLanguage)) (\(appState.defaultWatermarkPosition.title(for: appState.currentLanguage)))")
                                    .tag(WatermarkPosition?.none)
                                ForEach(WatermarkPosition.allCases) { pos in
                                    Text(pos.title(for: appState.currentLanguage)).tag(WatermarkPosition?.some(pos))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)
                        }
                        
                        // In-Photo Watermark Theme Override
                        HStack {
                            Text(L10n.t(.inPhotoWatermarks, lang: appState.currentLanguage))
                            Spacer()
                            Picker("", selection: Binding<WatermarkTheme?>(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return nil }
                                    return appState.images[selectedIndex].customInPhotoWatermarkTheme 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    appState.images[selectedIndex].customInPhotoWatermarkTheme = $0
                                    appState.bumpPreview()
                                }
                            )) {
                                Text(L10n.t(.auto, lang: appState.currentLanguage)).tag(WatermarkTheme?.none)
                                ForEach(WatermarkTheme.allCases) { theme in
                                    Text(theme.title(for: appState.currentLanguage)).tag(WatermarkTheme?.some(theme))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)
                        }
                        
                        // Frame Watermark Theme Override
                        HStack {
                            Text(L10n.t(.frameWatermarks, lang: appState.currentLanguage))
                            Spacer()
                            Picker("", selection: Binding<WatermarkTheme?>(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return nil }
                                    return appState.images[selectedIndex].customFrameWatermarkTheme 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    appState.images[selectedIndex].customFrameWatermarkTheme = $0
                                    appState.bumpPreview()
                                }
                            )) {
                                Text(L10n.t(.auto, lang: appState.currentLanguage)).tag(WatermarkTheme?.none)
                                ForEach(WatermarkTheme.allCases) { theme in
                                    Text(theme.title(for: appState.currentLanguage)).tag(WatermarkTheme?.some(theme))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 190)
                        }
                        
                        // In-Photo Watermark Size Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                let scaleVal = processable.customInPhotoWatermarkScale ?? appState.inPhotoWatermarkScale
                                Text("\(L10n.t(.inPhotoSize, lang: appState.currentLanguage)): \(Int(round(scaleVal * 100)))%")
                                Spacer()
                                if processable.customInPhotoWatermarkScale != nil {
                                    Button(L10n.t(.auto, lang: appState.currentLanguage)) {
                                        guard selectedIndex < appState.images.count else { return }
                                        appState.images[selectedIndex].customInPhotoWatermarkScale = nil
                                        appState.bumpPreview()
                                        hapticFeedback()
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.accentColor)
                                }
                            }
                            Slider(value: Binding(
                                get: { 
                                    guard selectedIndex < appState.images.count else { return appState.inPhotoWatermarkScale }
                                    return appState.images[selectedIndex].customInPhotoWatermarkScale ?? appState.inPhotoWatermarkScale 
                                },
                                set: { 
                                    guard selectedIndex < appState.images.count else { return }
                                    let snapped = (round($0 * 10.0) / 10.0)
                                    appState.images[selectedIndex].customInPhotoWatermarkScale = snapped
                                    appState.bumpPreview()
                                }
                            ), in: 0.5...1.5, step: 0.1)
                            .onChange(of: processable.customInPhotoWatermarkScale) { hapticFeedback() }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(L10n.t(.noPhotoSelected, lang: appState.currentLanguage))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Global Defaults Inspector
    
    private var globalDefaultsInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section 1: Frame Defaults
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t(.frameSettings, lang: appState.currentLanguage))
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                HStack {
                    Text(L10n.t(.themeColor, lang: appState.currentLanguage))
                    Spacer()
                    Picker("", selection: $appState.themeColor) {
                        ForEach(ThemeColor.allCases) { color in
                            Text(color.title(for: appState.currentLanguage)).tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 190)
                }
                
                HStack {
                    Text(L10n.t(.defaultStyle, lang: appState.currentLanguage))
                    Spacer()
                    Picker("", selection: $appState.defaultFrameStyle) {
                        ForEach(FrameStyle.allCases) { style in
                            Text(style.title(for: appState.currentLanguage)).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 190)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L10n.t(.frameWidth, lang: appState.currentLanguage)): \(appState.frameWidthPercentage, specifier: "%.1f")%")
                    Slider(value: Binding(
                        get: { appState.frameWidthPercentage },
                        set: { appState.frameWidthPercentage = (round($0 * 10.0) / 10.0) }
                    ), in: 0.0...5.0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            
            Divider()
                .padding(.horizontal, 14)
            
            // Section 2: Watermark Layout Defaults
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t(.watermarkSettings, lang: appState.currentLanguage))
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                HStack {
                    Text(L10n.t(.defaultPosition, lang: appState.currentLanguage))
                    Spacer()
                    Picker("", selection: $appState.defaultWatermarkPosition) {
                        ForEach(WatermarkPosition.allCases) { pos in
                            Text(pos.title(for: appState.currentLanguage)).tag(pos)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 190)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L10n.t(.inPhotoSize, lang: appState.currentLanguage)): \(Int(round(appState.inPhotoWatermarkScale * 100)))%")
                    Slider(value: $appState.inPhotoWatermarkScale, in: 0.5...1.5, step: 0.1)
                        .onChange(of: appState.inPhotoWatermarkScale) { hapticFeedback() }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L10n.t(.inPhotoOpacity, lang: appState.currentLanguage)): \(Int(round(appState.inPhotoWatermarkOpacity * 100)))%")
                    Slider(value: $appState.inPhotoWatermarkOpacity, in: 0.0...1.0, step: 0.1)
                        .onChange(of: appState.inPhotoWatermarkOpacity) { hapticFeedback() }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L10n.t(.frameSize, lang: appState.currentLanguage)): \(Int(round(appState.frameWatermarkScale * 100)))%")
                    Slider(value: $appState.frameWatermarkScale, in: 0.5...1.5, step: 0.1)
                        .onChange(of: appState.frameWatermarkScale) { hapticFeedback() }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L10n.t(.frameOpacity, lang: appState.currentLanguage)): \(Int(round(appState.frameWatermarkOpacity * 100)))%")
                    Slider(value: $appState.frameWatermarkOpacity, in: 0.0...1.0, step: 0.1)
                        .onChange(of: appState.frameWatermarkOpacity) { hapticFeedback() }
                }
            }
            .padding(.horizontal, 14)
            
            Divider()
                .padding(.horizontal, 14)
            
            // Section 3: Watermark Library & Visual Slots
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t(.customWatermarks, lang: appState.currentLanguage))
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                // Explanatory Tip Box on Dark vs Light Pairing
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.body)
                        .padding(.top, 1)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t(.watermarkNoticeTitle, lang: appState.currentLanguage))
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(L10n.t(.watermarkNoticeBody, lang: appState.currentLanguage))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                // In-Photo Watermarks Group
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t(.inPhotoWatermarks, lang: appState.currentLanguage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    // White / Light Watermark Slot (Dark background)
                    watermarkSlotCard(
                        title: L10n.t(.lightWatermarkTitle, lang: appState.currentLanguage),
                        subtitle: L10n.t(.lightWatermarkSub, lang: appState.currentLanguage),
                        url: appState.customInPhotoLightURL,
                        isLightAsset: true,
                        onSelect: {
                            selectFile { url in 
                                appState.customInPhotoLightURL = url 
                                appState.bumpPreview()
                            }
                        },
                        onClear: { 
                            appState.customInPhotoLightURL = nil 
                            appState.bumpPreview()
                        }
                    )
                    
                    // Black / Dark Watermark Slot (Light background)
                    watermarkSlotCard(
                        title: L10n.t(.darkWatermarkTitle, lang: appState.currentLanguage),
                        subtitle: L10n.t(.darkWatermarkSub, lang: appState.currentLanguage),
                        url: appState.customInPhotoDarkURL,
                        isLightAsset: false,
                        onSelect: {
                            selectFile { url in 
                                appState.customInPhotoDarkURL = url 
                                appState.bumpPreview()
                            }
                        },
                        onClear: { 
                            appState.customInPhotoDarkURL = nil 
                            appState.bumpPreview()
                        }
                    )
                }
                
                // Frame Watermarks Group
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t(.frameWatermarks, lang: appState.currentLanguage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    // White / Light Frame Watermark Slot
                    watermarkSlotCard(
                        title: L10n.t(.lightWatermarkTitle, lang: appState.currentLanguage),
                        subtitle: L10n.t(.lightWatermarkSub, lang: appState.currentLanguage),
                        url: appState.customFrameLightURL,
                        isLightAsset: true,
                        onSelect: {
                            selectFile { url in 
                                appState.customFrameLightURL = url 
                                appState.bumpPreview()
                            }
                        },
                        onClear: { 
                            appState.customFrameLightURL = nil 
                            appState.bumpPreview()
                        }
                    )
                    
                    // Black / Dark Frame Watermark Slot
                    watermarkSlotCard(
                        title: L10n.t(.darkWatermarkTitle, lang: appState.currentLanguage),
                        subtitle: L10n.t(.darkWatermarkSub, lang: appState.currentLanguage),
                        url: appState.customFrameDarkURL,
                        isLightAsset: false,
                        onSelect: {
                            selectFile { url in 
                                appState.customFrameDarkURL = url 
                                appState.bumpPreview()
                            }
                        },
                        onClear: { 
                            appState.customFrameDarkURL = nil 
                            appState.bumpPreview()
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Watermark Slot Card
    
    private func watermarkSlotCard(
        title: String,
        subtitle: String,
        url: URL?,
        isLightAsset: Bool,
        onSelect: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            // Visual Preview Box with appropriate contrast background
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isLightAsset ? Color.black.opacity(0.85) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if let url = url, let img = NSImage(contentsOf: url) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "watermark")
                        .font(.caption)
                        .foregroundColor(isLightAsset ? .white.opacity(0.4) : .black.opacity(0.4))
                }
            }
            .frame(width: 44, height: 38)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(isLightAsset ? "● 白" : "● 黑")
                        .font(.system(size: 10))
                        .foregroundColor(isLightAsset ? .white : .black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isLightAsset ? Color.black : Color.gray.opacity(0.25), in: Capsule())
                }
                
                if let url = url {
                    Text(url.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if url != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.t(.clear, lang: appState.currentLanguage))
            } else {
                Button(action: onSelect) {
                    Text(L10n.t(.select, lang: appState.currentLanguage))
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .help(subtitle)
    }
    
    private func selectFile(completion: @escaping (URL?) -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [
                .png,
                .jpeg,
                .svg,
                .pdf,
                .webP,
                .tiff,
                .image
            ]
            panel.title = L10n.t(.selectWatermarkTitle, lang: appState.currentLanguage)
            panel.message = L10n.t(.selectWatermarkMessage, lang: appState.currentLanguage)
            panel.prompt = L10n.t(.selectPrompt, lang: appState.currentLanguage)
            
            if panel.runModal() == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
    
    private func hapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}

// MARK: - Window Accessor for Native macOS Window Properties

struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
