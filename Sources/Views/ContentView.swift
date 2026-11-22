import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var isTargeted = false
    
    var body: some View {
        NavigationSplitView {
            ImageListView(appState: appState)
                .navigationSplitViewColumnWidth(min: 150, ideal: 150, max: 200)
        } content: {
            MainPreviewArea(appState: appState, isTargeted: $isTargeted)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Export Selected") {
                            exportSelected()
                        }
                        .disabled(appState.selectedImageID == nil)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Export All") {
                            exportAll()
                        }
                        .disabled(appState.images.isEmpty)
                    }
                }
        } detail: {
            SettingsInspector(appState: appState)
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        }
        .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
            loadProviders(providers)
            return true
        }
    }
    
    private func loadProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        appState.addImages(from: [url])
                    }
                }
            }
        }
    }
    
    private func exportSelected() {
        guard let index = appState.selectedImageIndex else { return }
        let processable = appState.images[index]
        
        Task { @MainActor in
            // Give SwiftUI a moment to complete the button click event
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.jpeg, .png]
            let originalName = processable.originalURL.deletingPathExtension().lastPathComponent
            panel.nameFieldStringValue = "\(originalName)_tFrame.jpg"
            
            if panel.runModal() == .OK, let url = panel.url {
                // Yield to allow panel to dismiss
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                if let finalImage = await ImageProcessor.shared.process(image: processable, state: appState) {
                    save(image: finalImage, to: url)
                }
            }
        }
    }
    
    private func exportAll() {
        Task { @MainActor in
            // Give SwiftUI a moment to complete the button click event
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.canChooseFiles = false
            panel.prompt = "Select Export Folder"
            
            if panel.runModal() == .OK, let folderURL = panel.url {
                // Yield to allow panel to dismiss
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                for processable in appState.images {
                    await Task.yield() // Keep UI responsive during batch export
                    guard let finalImage = await ImageProcessor.shared.process(image: processable, state: appState) else { continue }
                    
                    let originalName = processable.originalURL.deletingPathExtension().lastPathComponent
                    let fileURL = folderURL.appendingPathComponent("\(originalName)_tFrame.jpg")
                    save(image: finalImage, to: fileURL)
                }
            }
        }
    }
    
    private func save(image: NSImage, to url: URL) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        let type: NSBitmapImageRep.FileType = url.pathExtension.lowercased() == "png" ? .png : .jpeg
        let properties: [NSBitmapImageRep.PropertyKey: Any] = type == .jpeg ? [.compressionFactor: 0.9] : [:]
        
        guard let data = bitmapRep.representation(using: type, properties: properties) else { return }
        try? data.write(to: url)
    }
}

struct ImageListView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack {
            List(selection: $appState.selectedImageID) {
                ForEach(appState.images) { img in
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                        Text(img.originalURL.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(img.id)
                    .contextMenu {
                        Button("Delete") {
                            appState.removeImage(id: img.id)
                        }
                    }
                }
                .onDelete { offsets in
                    appState.removeImages(at: offsets)
                }
            }
            
            if !appState.images.isEmpty {
                Button("Clear All") {
                    appState.clearAll()
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Images")
    }
}

struct SettingsInspector: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Global Theme") {
                Picker("Theme Color", selection: $appState.themeColor) {
                    ForEach(ThemeColor.allCases) { color in
                        Text(color.rawValue).tag(color)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Frame Settings") {
                Picker("Default Style", selection: $appState.defaultFrameStyle) {
                    ForEach(FrameStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Frame Width: \(appState.frameWidthPercentage, specifier: "%.1f")%")
                    Slider(value: $appState.frameWidthPercentage, in: 0.5...10.0, step: 0.1)
                }
            }
            
            Section("Watermark Settings") {
                Picker("Default Position", selection: $appState.defaultWatermarkPosition) {
                    ForEach(WatermarkPosition.allCases) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("In-Photo Size: \(Int(appState.inPhotoWatermarkScale * 100))%")
                    Slider(value: $appState.inPhotoWatermarkScale, in: 0.5...1.5, step: 0.1)
                        .onChange(of: appState.inPhotoWatermarkScale) { hapticFeedback() }
                }
                
                VStack(alignment: .leading) {
                    Text("In-Photo Opacity: \(Int(appState.inPhotoWatermarkOpacity * 100))%")
                    Slider(value: $appState.inPhotoWatermarkOpacity, in: 0.0...1.0, step: 0.1)
                        .onChange(of: appState.inPhotoWatermarkOpacity) { hapticFeedback() }
                }
                
                VStack(alignment: .leading) {
                    Text("Frame Opacity: \(Int(appState.frameWatermarkOpacity * 100))%")
                    Slider(value: $appState.frameWatermarkOpacity, in: 0.0...1.0, step: 0.1)
                        .onChange(of: appState.frameWatermarkOpacity) { hapticFeedback() }
                }
                
                VStack(alignment: .leading) {
                    Text("Frame Size: \(Int(appState.frameWatermarkScale * 100))%")
                    Slider(value: $appState.frameWatermarkScale, in: 0.5...1.5, step: 0.1)
                        .onChange(of: appState.frameWatermarkScale) { hapticFeedback() }
                }
            }
            
            Section("Custom Watermarks") {
                VStack(alignment: .leading) {
                    Text("In-Photo Watermarks").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text(appState.customInPhotoLightURL?.lastPathComponent ?? "Light: None")
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(appState.customInPhotoLightURL == nil ? "Select..." : "Clear") {
                            if appState.customInPhotoLightURL == nil {
                                selectFile { url in appState.customInPhotoLightURL = url }
                            } else {
                                appState.customInPhotoLightURL = nil
                            }
                        }
                    }
                    HStack {
                        Text(appState.customInPhotoDarkURL?.lastPathComponent ?? "Dark: None")
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(appState.customInPhotoDarkURL == nil ? "Select..." : "Clear") {
                            if appState.customInPhotoDarkURL == nil {
                                selectFile { url in appState.customInPhotoDarkURL = url }
                            } else {
                                appState.customInPhotoDarkURL = nil
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Frame Watermarks").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text(appState.customFrameLightURL?.lastPathComponent ?? "Light: None")
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(appState.customFrameLightURL == nil ? "Select..." : "Clear") {
                            if appState.customFrameLightURL == nil {
                                selectFile { url in appState.customFrameLightURL = url }
                            } else {
                                appState.customFrameLightURL = nil
                            }
                        }
                    }
                    HStack {
                        Text(appState.customFrameDarkURL?.lastPathComponent ?? "Dark: None")
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(appState.customFrameDarkURL == nil ? "Select..." : "Clear") {
                            if appState.customFrameDarkURL == nil {
                                selectFile { url in appState.customFrameDarkURL = url }
                            } else {
                                appState.customFrameDarkURL = nil
                            }
                        }
                    }
                }
            }
            
            if let selectedIndex = appState.selectedImageIndex {
                Section("Overrides (Selected Image)") {
                    Picker("Position", selection: Binding(
                        get: { 
                            guard selectedIndex < appState.images.count else { return appState.defaultWatermarkPosition }
                            return appState.images[selectedIndex].customWatermarkPosition ?? appState.defaultWatermarkPosition 
                        },
                        set: { 
                            if selectedIndex < appState.images.count {
                                appState.images[selectedIndex].customWatermarkPosition = $0 
                            }
                        }
                    )) {
                        ForEach(WatermarkPosition.allCases) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    
                    Picker("Style", selection: Binding(
                        get: {
                            guard selectedIndex < appState.images.count else { return appState.defaultFrameStyle }
                            return appState.images[selectedIndex].customFrameStyle ?? appState.defaultFrameStyle
                        },
                        set: {
                            if selectedIndex < appState.images.count {
                                appState.images[selectedIndex].customFrameStyle = $0
                            }
                        }
                    )) {
                        ForEach(FrameStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    
                    Picker("Theme Color", selection: Binding(
                        get: {
                            guard selectedIndex < appState.images.count else { return appState.themeColor }
                            return appState.images[selectedIndex].customThemeColor ?? appState.themeColor
                        },
                        set: {
                            if selectedIndex < appState.images.count {
                                appState.images[selectedIndex].customThemeColor = $0
                            }
                        }
                    )) {
                        ForEach(ThemeColor.allCases) { color in
                            Text(color.rawValue).tag(color)
                        }
                    }
                    
                    Picker("In-Photo Watermark", selection: Binding<WatermarkTheme?>(
                        get: {
                            guard selectedIndex < appState.images.count else { return nil }
                            return appState.images[selectedIndex].customInPhotoWatermarkTheme
                        },
                        set: {
                            if selectedIndex < appState.images.count {
                                appState.images[selectedIndex].customInPhotoWatermarkTheme = $0
                            }
                        }
                    )) {
                        Text("Auto").tag(WatermarkTheme?.none)
                        ForEach(WatermarkTheme.allCases) { theme in
                            Text(theme.rawValue).tag(WatermarkTheme?.some(theme))
                        }
                    }
                    
                    Picker("Frame Watermark", selection: Binding<WatermarkTheme?>(
                        get: {
                            guard selectedIndex < appState.images.count else { return nil }
                            return appState.images[selectedIndex].customFrameWatermarkTheme
                        },
                        set: {
                            if selectedIndex < appState.images.count {
                                appState.images[selectedIndex].customFrameWatermarkTheme = $0
                            }
                        }
                    )) {
                        Text("Auto").tag(WatermarkTheme?.none)
                        ForEach(WatermarkTheme.allCases) { theme in
                            Text(theme.rawValue).tag(WatermarkTheme?.some(theme))
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            let scaleVal = selectedIndex < appState.images.count ? (appState.images[selectedIndex].customInPhotoWatermarkScale ?? appState.inPhotoWatermarkScale) : appState.inPhotoWatermarkScale
                            Text("In-Photo Size: \(Int(scaleVal * 100))%")
                            Spacer()
                            if selectedIndex < appState.images.count, appState.images[selectedIndex].customInPhotoWatermarkScale != nil {
                                Button("Auto") { appState.images[selectedIndex].customInPhotoWatermarkScale = nil }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Slider(value: Binding(
                            get: { 
                                guard selectedIndex < appState.images.count else { return appState.inPhotoWatermarkScale }
                                return appState.images[selectedIndex].customInPhotoWatermarkScale ?? appState.inPhotoWatermarkScale 
                            },
                            set: { if selectedIndex < appState.images.count { appState.images[selectedIndex].customInPhotoWatermarkScale = $0 } }
                        ), in: 0.5...1.5, step: 0.1)
                        .onChange(of: selectedIndex < appState.images.count ? appState.images[selectedIndex].customInPhotoWatermarkScale : nil) { hapticFeedback() }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            let scaleVal = selectedIndex < appState.images.count ? (appState.images[selectedIndex].customFrameWatermarkScale ?? appState.frameWatermarkScale) : appState.frameWatermarkScale
                            Text("Frame Size: \(Int(scaleVal * 100))%")
                            Spacer()
                            if selectedIndex < appState.images.count, appState.images[selectedIndex].customFrameWatermarkScale != nil {
                                Button("Auto") { appState.images[selectedIndex].customFrameWatermarkScale = nil }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Slider(value: Binding(
                            get: { 
                                guard selectedIndex < appState.images.count else { return appState.frameWatermarkScale }
                                return appState.images[selectedIndex].customFrameWatermarkScale ?? appState.frameWatermarkScale 
                            },
                            set: { if selectedIndex < appState.images.count { appState.images[selectedIndex].customFrameWatermarkScale = $0 } }
                        ), in: 0.5...1.5, step: 0.1)
                        .onChange(of: selectedIndex < appState.images.count ? appState.images[selectedIndex].customFrameWatermarkScale : nil) { hapticFeedback() }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            let opacityVal = selectedIndex < appState.images.count ? (appState.images[selectedIndex].customInPhotoWatermarkOpacity ?? appState.inPhotoWatermarkOpacity) : appState.inPhotoWatermarkOpacity
                            Text("In-Photo Opacity: \(Int(opacityVal * 100))%")
                            Spacer()
                            if selectedIndex < appState.images.count, appState.images[selectedIndex].customInPhotoWatermarkOpacity != nil {
                                Button("Auto") { appState.images[selectedIndex].customInPhotoWatermarkOpacity = nil }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Slider(value: Binding(
                            get: { 
                                guard selectedIndex < appState.images.count else { return appState.inPhotoWatermarkOpacity }
                                return appState.images[selectedIndex].customInPhotoWatermarkOpacity ?? appState.inPhotoWatermarkOpacity 
                            },
                            set: { if selectedIndex < appState.images.count { appState.images[selectedIndex].customInPhotoWatermarkOpacity = $0 } }
                        ), in: 0.0...1.0, step: 0.1)
                        .onChange(of: selectedIndex < appState.images.count ? appState.images[selectedIndex].customInPhotoWatermarkOpacity : nil) { hapticFeedback() }
                    }
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
    
    private func hapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
    
    private func selectFile(completion: @escaping (URL?) -> Void) {
        Task { @MainActor in
            // Give SwiftUI a moment to complete the button click event
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.png]
            
            if panel.runModal() == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}

struct MainPreviewArea: View {
    @ObservedObject var appState: AppState
    @Binding var isTargeted: Bool
    
    @State private var previewImage: NSImage?
    
    private var previewTrigger: Int {
        var hasher = Hasher()
        hasher.combine(appState.selectedImageID)
        hasher.combine(appState.frameWidthPercentage)
        hasher.combine(appState.themeColor)
        hasher.combine(appState.defaultWatermarkPosition)
        hasher.combine(appState.inPhotoWatermarkOpacity)
        hasher.combine(appState.frameWatermarkOpacity)
        hasher.combine(appState.inPhotoWatermarkScale)
        hasher.combine(appState.frameWatermarkScale)
        hasher.combine(appState.defaultFrameStyle)
        
        if let idx = appState.selectedImageIndex {
            let img = appState.images[idx]
            hasher.combine(img.customWatermarkPosition)
            hasher.combine(img.customFrameStyle)
            hasher.combine(img.customThemeColor)
            hasher.combine(img.customInPhotoWatermarkTheme)
            hasher.combine(img.customFrameWatermarkTheme)
            hasher.combine(img.customInPhotoWatermarkScale)
            hasher.combine(img.customFrameWatermarkScale)
            hasher.combine(img.customInPhotoWatermarkOpacity)
        }
        return hasher.finalize()
    }
    
    var body: some View {
        ZStack {
            if isTargeted {
                Color.accentColor.opacity(0.2)
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
                        .padding()
                } else {
                    ProgressView("Processing Preview...")
                }
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Drag and Drop Photos Here")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
            }
        }
        .task(id: previewTrigger) {
            guard let index = appState.selectedImageIndex else {
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
