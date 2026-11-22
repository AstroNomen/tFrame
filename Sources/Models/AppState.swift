import SwiftUI
import UniformTypeIdentifiers

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case bottomRight = "Bottom Right"
    case bottomLeft = "Bottom Left"
    
    var id: String { self.rawValue }
}

enum ThemeColor: String, CaseIterable, Identifiable {
    case black = "Black"
    case white = "White"
    
    var id: String { self.rawValue }
}

enum FrameStyle: String, CaseIterable, Identifiable {
    case full = "Full Frame"
    case cinematic = "Cinematic (Top/Bottom)"
    
    var id: String { self.rawValue }
}

enum WatermarkTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
}

struct ProcessedImage: Identifiable {
    let id = UUID()
    let originalURL: URL
    let originalImage: NSImage
    var processedImage: NSImage?
    
    // Per-image overrides (optional)
    var customWatermarkPosition: WatermarkPosition?
    var customFrameStyle: FrameStyle?
    var customThemeColor: ThemeColor?
    var customInPhotoWatermarkTheme: WatermarkTheme?
    var customFrameWatermarkTheme: WatermarkTheme?
    var customInPhotoWatermarkScale: Double?
    var customInPhotoWatermarkOpacity: Double?
    var customFrameWatermarkScale: Double?
}

@MainActor
class AppState: ObservableObject {
    @Published var images: [ProcessedImage] = []
    @Published var selectedImageID: UUID?
    
    // Global Settings
    @Published var frameWidthPercentage: Double = 2.5 // 2.5% of width+height
    @Published var defaultFrameStyle: FrameStyle = .full
    @Published var defaultWatermarkPosition: WatermarkPosition = .bottomRight
    @Published var themeColor: ThemeColor = .black
    @Published var inPhotoWatermarkOpacity: Double = 0.8
    @Published var frameWatermarkOpacity: Double = 1.0
    @Published var inPhotoWatermarkScale: Double = 1.0 // 0.5 to 1.5 multiplier
    @Published var frameWatermarkScale: Double = 1.0 // 0.5 to 1.5 multiplier
    
    // Custom Watermarks
    @Published var customInPhotoLightURL: URL?
    @Published var customInPhotoDarkURL: URL?
    @Published var customFrameLightURL: URL?
    @Published var customFrameDarkURL: URL?
    
    var selectedImageIndex: Int? {
        images.firstIndex(where: { $0.id == selectedImageID })
    }
    
    func addImages(from urls: [URL]) {
        for url in urls {
            if let nsImage = NSImage(contentsOf: url) {
                let img = ProcessedImage(originalURL: url, originalImage: nsImage)
                images.append(img)
                if selectedImageID == nil {
                    selectedImageID = img.id
                }
            }
        }
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
    }
    
    private func removeImage(at idx: Int) {
        images.remove(at: idx)
        if images.isEmpty {
            selectedImageID = nil
        } else {
            selectedImageID = images[min(idx, images.count - 1)].id
        }
    }
    
    func clearAll() {
        images.removeAll()
        selectedImageID = nil
    }
}
