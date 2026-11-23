import SwiftUI
import UniformTypeIdentifiers
import ImageIO

extension Notification.Name {
    static let openSettings = Notification.Name("tFrame_openSettings")
}

enum NavigationTab: String, CaseIterable, Identifiable {
    case frameWatermark = "frameWatermark"
    case collage = "collage"
    
    var id: String { rawValue }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .frameWatermark: return L10n.t(.tabFrameWatermark, lang: lang)
        case .collage: return L10n.t(.tabCollage, lang: lang)
        }
    }
    
    var icon: String {
        switch self {
        case .frameWatermark: return "photo.artframe"
        case .collage: return "square.grid.2x2"
        }
    }
}

enum InspectorScope: String, CaseIterable, Identifiable {
    case current = "current"
    case global = "global"
    
    var id: String { rawValue }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .current: return L10n.t(.scopeThisPhoto, lang: lang)
        case .global: return L10n.t(.scopeGlobal, lang: lang)
        }
    }
}

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case bottomRight = "Bottom Right"
    case bottomLeft = "Bottom Left"
    
    var id: String { self.rawValue }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .bottomRight: return L10n.t(.bottomRight, lang: lang)
        case .bottomLeft: return L10n.t(.bottomLeft, lang: lang)
        }
    }
}

enum ThemeColor: String, CaseIterable, Identifiable {
    case black = "Black"
    case white = "White"
    
    var id: String { self.rawValue }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .black: return L10n.t(.black, lang: lang)
        case .white: return L10n.t(.white, lang: lang)
        }
    }
}

enum CinematicAspectRatio: String, CaseIterable, Identifiable {
    case free = "Free (Slider)"
    case r16_9 = "16:9"
    case r19_5_9 = "19.5:9"
    case r21_9 = "21:9"
    
    var id: String { self.rawValue }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .free: return L10n.t(.cinematicRatioFree, lang: lang)
        case .r16_9: return "16:9 (电脑/显示器)"
        case .r19_5_9: return "19.5:9 (iPhone全屏)"
        case .r21_9: return "21:9 (带鱼屏/电影)"
        }
    }
    
    var ratioValue: Double? {
        switch self {
        case .free: return nil
        case .r16_9: return 16.0 / 9.0
        case .r19_5_9: return 19.5 / 9.0
        case .r21_9: return 21.0 / 9.0
        }
    }
}

enum FrameStyle: String, CaseIterable, Identifiable {
    case full = "Full Frame"
    case cinematic = "Cinematic (Top/Bottom)"
    case polaroid = "Polaroid"
    case label = "Bottom Label"
    case sideLabelLeft = "Side Label (Left)"
    case sideLabelRight = "Side Label (Right)"
    case stamp = "Stamp"
    case film = "Film Sprockets"
    case square = "Square (1:1)"
    
    var id: String { self.rawValue }
    
    var isFixedThickness: Bool {
        switch self {
        case .polaroid, .label, .sideLabelLeft, .sideLabelRight, .stamp, .film, .square:
            return true
        case .full, .cinematic:
            return false
        }
    }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .full: return L10n.t(.fullFrame, lang: lang)
        case .cinematic: return L10n.t(.cinematic, lang: lang)
        case .polaroid: return L10n.t(.polaroid, lang: lang)
        case .label: return L10n.t(.bottomLabel, lang: lang)
        case .sideLabelLeft: return L10n.t(.sideLabelLeft, lang: lang)
        case .sideLabelRight: return L10n.t(.sideLabelRight, lang: lang)
        case .stamp: return L10n.t(.stamp, lang: lang)
        case .film: return L10n.t(.filmSprockets, lang: lang)
        case .square: return L10n.t(.squareFrame, lang: lang)
        }
    }
    
    func insets(width: Double, height: Double, percentage: Double, cinematicRatio: CinematicAspectRatio = .free) -> (left: Double, right: Double, top: Double, bottom: Double) {
        let frameThickness = round((width + height) * (percentage / 100.0))
        let minDim = min(width, height)
        let maxDim = max(width, height)
        
        switch self {
        case .full:
            return (frameThickness, frameThickness, frameThickness, frameThickness)
        case .cinematic:
            if let targetRatio = cinematicRatio.ratioValue {
                let isLandscape = width >= height
                // 当前图片的长宽比
                let currentRatio = isLandscape ? (width / height) : (height / width)
                
                if currentRatio >= targetRatio {
                    // 原图比目标画幅更宽（如 XPAN 65:24 放入 16:9/21:9 容器）：上下填充黑边 (Letterbox)
                    let targetH = isLandscape ? round(width / targetRatio) : round(width * targetRatio)
                    let padH = max(0.0, targetH - height)
                    let top = round(padH / 2.0)
                    let bottom = padH - top
                    return (0.0, 0.0, top, bottom)
                } else {
                    // 原图比目标画幅更窄：左右填充黑边 (Pillarbox)
                    let targetW = isLandscape ? round(height * targetRatio) : round(height / targetRatio)
                    let padW = max(0.0, targetW - width)
                    let left = round(padW / 2.0)
                    let right = padW - left
                    return (left, right, 0.0, 0.0)
                }
            } else {
                return (0.0, 0.0, frameThickness, frameThickness)
            }
        case .polaroid:
            // 拍立得经典相纸比例：左、右、上等宽窄白边，底边为较宽边框（约3.5倍侧边）
            let side = round(minDim * 0.045)
            let bottom = round(minDim * 0.16)
            return (side, side, side, bottom)
        case .label:
            // 底部标签样式：类似手机相机水印边框，左右上无边，底边一条利落边框
            let bottom = round(minDim * 0.09)
            return (0.0, 0.0, 0.0, bottom)
        case .sideLabelLeft:
            // 侧边标签(居左)：左侧约 9% 宽度画册侧边栏，上右下无边
            let side = round(minDim * 0.09)
            return (side, 0.0, 0.0, 0.0)
        case .sideLabelRight:
            // 侧边标签(居右)：右侧约 9% 宽度画册侧边栏，上左下无边
            let side = round(minDim * 0.09)
            return (0.0, side, 0.0, 0.0)
        case .stamp:
            // 邮票锯齿边：四周留出约 5.5% 的规整邮票边框，外缘带物理打孔圆孔锯齿
            let border = round(minDim * 0.055)
            return (border, border, border, border)
        case .film:
            // 135胶片片基：依据真实底片物理规律自动适配方向
            // - 横拍（width >= height）：胶片水平走卷，齿孔位于画面的【上下两侧】
            // - 竖拍（height > width）：相机旋转90°竖构图，胶片垂直走卷，齿孔位于画面的【左右两侧】
            if width >= height {
                let rebate = round(height * 0.23)
                return (0.0, 0.0, rebate, rebate)
            } else {
                let rebate = round(width * 0.23)
                return (rebate, rebate, 0.0, 0.0)
            }
        case .square:
            // 正方形画框：自适应填充成 1:1，长边两侧保留约 4% 的装裱留白，照片绝对居中
            let targetSide = round(maxDim * 1.08)
            let padW = max(0.0, targetSide - width)
            let padH = max(0.0, targetSide - height)
            let left = round(padW / 2.0)
            let right = padW - left
            let bottom = round(padH / 2.0)
            let top = padH - bottom
            return (left, right, top, bottom)
        }
    }
}

enum WatermarkTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    func title(for lang: AppLanguage) -> String {
        switch self {
        case .light: return L10n.t(.light, lang: lang)
        case .dark: return L10n.t(.dark, lang: lang)
        }
    }
}

struct ProcessedImage: Identifiable {
    let id = UUID()
    let originalURL: URL
    let originalImage: NSImage
    var processedImage: NSImage?
    
    // Pixel resolution and size info
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSizeBytes: Int64
    
    // Per-image overrides (optional)
    var customWatermarkPosition: WatermarkPosition?
    var customFrameStyle: FrameStyle?
    var customThemeColor: ThemeColor?
    var customInPhotoWatermarkTheme: WatermarkTheme?
    var customFrameWatermarkTheme: WatermarkTheme?
    var customInPhotoWatermarkScale: Double?
    var customInPhotoWatermarkOpacity: Double?
    var customFrameWatermarkScale: Double?
    var customCinematicRatio: CinematicAspectRatio?
    var customExportQuality: ExportQuality?
    
    var hasCustomOverrides: Bool {
        customWatermarkPosition != nil ||
        customFrameStyle != nil ||
        customCinematicRatio != nil ||
        customThemeColor != nil ||
        customInPhotoWatermarkTheme != nil ||
        customFrameWatermarkTheme != nil ||
        customInPhotoWatermarkScale != nil ||
        customInPhotoWatermarkOpacity != nil ||
        customFrameWatermarkScale != nil ||
        customExportQuality != nil
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: NavigationTab = .frameWatermark
    @Published var inspectorScope: InspectorScope = .global
    
    @Published var images: [ProcessedImage] = []
    @Published var selectedImageID: UUID?
    
    // Preview bump counter to guarantee immediate preview rendering even with 1 photo
    @Published var previewVersion: Int = 0
    
    // Language & Preference
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
            bumpPreview()
        }
    }
    
    // Global Settings
    @Published var defaultExportQuality: ExportQuality {
        didSet {
            UserDefaults.standard.set(defaultExportQuality.rawValue, forKey: "DefaultExportQuality")
            bumpPreview()
        }
    }
    
    @Published var frameWidthPercentage: Double = 1.2 { didSet { bumpPreview() } }
    @Published var defaultFrameStyle: FrameStyle = .full { didSet { bumpPreview() } }
    @Published var defaultCinematicRatio: CinematicAspectRatio = .free { didSet { bumpPreview() } }
    @Published var defaultWatermarkPosition: WatermarkPosition = .bottomRight { didSet { bumpPreview() } }
    @Published var themeColor: ThemeColor = .black { didSet { bumpPreview() } }
    @Published var inPhotoWatermarkOpacity: Double = 0.8 { didSet { bumpPreview() } }
    @Published var frameWatermarkOpacity: Double = 1.0 { didSet { bumpPreview() } }
    @Published var inPhotoWatermarkScale: Double = 1.0 { didSet { bumpPreview() } }
    @Published var frameWatermarkScale: Double = 1.0 { didSet { bumpPreview() } }
    
    // Custom Watermarks
    @Published var customInPhotoLightURL: URL? { didSet { bumpPreview() } }
    @Published var customInPhotoDarkURL: URL? { didSet { bumpPreview() } }
    @Published var customFrameLightURL: URL? { didSet { bumpPreview() } }
    @Published var customFrameDarkURL: URL? { didSet { bumpPreview() } }
    
    init() {
        let savedLang = UserDefaults.standard.string(forKey: "AppLanguage") ?? AppLanguage.zh.rawValue
        self.currentLanguage = AppLanguage(rawValue: savedLang) ?? .zh
        
        let savedQuality = UserDefaults.standard.string(forKey: "DefaultExportQuality") ?? ExportQuality.high.rawValue
        self.defaultExportQuality = ExportQuality(rawValue: savedQuality) ?? .high
    }
    
    func bumpPreview() {
        previewVersion &+= 1
    }
    
    var selectedImageIndex: Int? {
        images.firstIndex(where: { $0.id == selectedImageID })
    }
    
    var selectedImage: ProcessedImage? {
        guard let idx = selectedImageIndex, idx < images.count else { return nil }
        return images[idx]
    }
    
    func selectNextImage() {
        guard let idx = selectedImageIndex, !images.isEmpty else { return }
        let nextIdx = min(idx + 1, images.count - 1)
        selectedImageID = images[nextIdx].id
    }
    
    func selectPreviousImage() {
        guard let idx = selectedImageIndex, !images.isEmpty else { return }
        let prevIdx = max(idx - 1, 0)
        selectedImageID = images[prevIdx].id
    }
    
    func resetCurrentPhotoOverrides() {
        guard let idx = selectedImageIndex, idx < images.count else { return }
        images[idx].customWatermarkPosition = nil
        images[idx].customFrameStyle = nil
        images[idx].customCinematicRatio = nil
        images[idx].customThemeColor = nil
        images[idx].customInPhotoWatermarkTheme = nil
        images[idx].customFrameWatermarkTheme = nil
        images[idx].customInPhotoWatermarkScale = nil
        images[idx].customInPhotoWatermarkOpacity = nil
        images[idx].customFrameWatermarkScale = nil
        images[idx].customExportQuality = nil
        bumpPreview()
    }
    
    func addImages(from urls: [URL]) {
        for url in urls {
            var pWidth = 0
            var pHeight = 0
            var fileSize: Int64 = 0
            
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                fileSize = Int64(size)
            }
            
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                let w = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
                let h = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
                let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
                
                if orientation >= 5 && orientation <= 8 {
                    pWidth = h
                    pHeight = w
                } else {
                    pWidth = w
                    pHeight = h
                }
            }
            
            if let nsImage = NSImage(contentsOf: url) {
                if pWidth == 0 || pHeight == 0 {
                    pWidth = Int(nsImage.size.width)
                    pHeight = Int(nsImage.size.height)
                }
                let img = ProcessedImage(originalURL: url,
                                         originalImage: nsImage,
                                         pixelWidth: pWidth,
                                         pixelHeight: pHeight,
                                         fileSizeBytes: fileSize)
                images.append(img)
                if selectedImageID == nil {
                    selectedImageID = img.id
                }
            }
        }
        bumpPreview()
    }
    
    func removeSelectedImage() {
        if let idx = selectedImageIndex {
            removeImage(at: idx)
        }
    }
    
    func removeImage(id: UUID) {
        if let idx = images.firstIndex(where: { $0.id == id }) {
            removeImage(at: idx)
        }
    }
    
    func removeImages(at offsets: IndexSet) {
        images.remove(atOffsets: offsets)
        if let id = selectedImageID, !images.contains(where: { $0.id == id }) {
            selectedImageID = images.first?.id
        }
        bumpPreview()
    }
    
    private func removeImage(at idx: Int) {
        images.remove(at: idx)
        if images.isEmpty {
            selectedImageID = nil
        } else {
            selectedImageID = images[min(idx, images.count - 1)].id
        }
        bumpPreview()
    }
    
    func clearAll() {
        images.removeAll()
        selectedImageID = nil
        bumpPreview()
    }
    
    // MARK: - Dimensions & File Size Estimations
    
    func effectiveQuality(for image: ProcessedImage) -> ExportQuality {
        return image.customExportQuality ?? defaultExportQuality
    }
    
    func effectiveDimensions(for image: ProcessedImage) -> (width: Int, height: Int) {
        let w = Double(image.pixelWidth)
        let h = Double(image.pixelHeight)
        guard w > 0, h > 0 else { return (image.pixelWidth, image.pixelHeight) }
        
        let style = image.customFrameStyle ?? defaultFrameStyle
        let cinematicRatio = image.customCinematicRatio ?? defaultCinematicRatio
        let insets = style.insets(width: w, height: h, percentage: frameWidthPercentage, cinematicRatio: cinematicRatio)
        
        let totalW = Int(w + insets.left + insets.right)
        let totalH = Int(h + insets.top + insets.bottom)
        return (totalW, totalH)
    }
    
    func estimatedFileSize(for image: ProcessedImage) -> Int64 {
        let (totalW, totalH) = effectiveDimensions(for: image)
        let quality = effectiveQuality(for: image)
        let totalPixels = Double(totalW * totalH)
        guard totalPixels > 0 else { return 0 }
        
        let baseBytesPerPixel: Double
        switch quality {
        case .lossless:
            baseBytesPerPixel = 0.65
        case .high:
            baseBytesPerPixel = 0.32
        case .medium:
            baseBytesPerPixel = 0.16
        case .low:
            baseBytesPerPixel = 0.08
        }
        
        if image.fileSizeBytes > 0 && image.pixelWidth > 0 && image.pixelHeight > 0 {
            let origBPP = Double(image.fileSizeBytes) / Double(image.pixelWidth * image.pixelHeight)
            let factor = min(max(origBPP / 0.35, 0.65), 1.5)
            return Int64(totalPixels * baseBytesPerPixel * factor)
        }
        
        return Int64(totalPixels * baseBytesPerPixel)
    }
    
    func totalEstimatedFileSize() -> Int64 {
        return images.reduce(0) { $0 + estimatedFileSize(for: $1) }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 KB" }
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
}
