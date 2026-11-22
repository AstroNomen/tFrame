import Cocoa
import CoreGraphics

@MainActor
final class ImageProcessor {
    static let shared = ImageProcessor()
    
    // Default watermark names
    private let defaultFrameWmBlack = "TimeSlice_GalleryLabel_Web"
    private let defaultFrameWmWhite = "TimeSlice_GalleryLabel_Web_W"
    private let defaultInPhotoWmBlack = "TimeSlice_BK"
    private let defaultInPhotoWmWhite = "TimeSlice_W"
    
    func process(image processable: ProcessedImage, state: AppState) async -> NSImage? {
        guard let cgImage = processable.originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Calculate frame width based on user percentage
        let frameThickness = (width + height) * CGFloat(state.frameWidthPercentage / 100.0)
        let style = processable.customFrameStyle ?? state.defaultFrameStyle
        
        let frameLeftRight = style == .cinematic ? 0.0 : frameThickness
        let frameTopBottom = frameThickness
        
        let totalWidth = width + frameLeftRight * 2
        let totalHeight = height + frameTopBottom * 2
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(data: nil,
                                      width: Int(totalWidth),
                                      height: Int(totalHeight),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        // Draw background (frame)
        let theme = processable.customThemeColor ?? state.themeColor
        let frameColor = theme == .black ? NSColor.black.cgColor : NSColor.white.cgColor
        context.setFillColor(frameColor)
        context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        
        // Draw original photo
        let photoRect = CGRect(x: frameLeftRight, y: frameTopBottom, width: width, height: height)
        context.draw(cgImage, in: photoRect)
        
        // Safe margin from the photo's edge
        // Use frameTopBottom as a baseline for safe margin so it scales reasonably
        let safeMargin = frameTopBottom * 0.4
        
        // 1. Draw Frame Watermark
        var frameWmRightX: CGFloat = 0
        if let frameWmCG = loadFrameWatermark(processable: processable, state: state) {
            let wmAspect = CGFloat(frameWmCG.width) / CGFloat(frameWmCG.height)
            let scale = processable.customFrameWatermarkScale ?? state.frameWatermarkScale
            let targetHeight = frameTopBottom * 0.35 * scale // 35% of the frame thickness * scale
            let targetWidth = targetHeight * wmAspect
            
            // Centered vertically in the bottom border
            let yPos = (frameTopBottom - targetHeight) / 2.0
            
            // Placed on the right, with a safe margin from the photo's right edge
            let xPos = photoRect.maxX - safeMargin - targetWidth
            frameWmRightX = xPos + targetWidth
            
            let wmRect = CGRect(x: xPos, y: yPos, width: targetWidth, height: targetHeight)
            
            context.setAlpha(CGFloat(state.frameWatermarkOpacity))
            context.draw(frameWmCG, in: wmRect)
        } else {
            // Default right boundary for alignment if no frame watermark
            frameWmRightX = photoRect.maxX - safeMargin
        }
        
        // 2. Draw In-Photo Watermark
        if let inPhotoWmCG = loadInPhotoWatermark(processable: processable, state: state) {
            let wmAspect = CGFloat(inPhotoWmCG.width) / CGFloat(inPhotoWmCG.height)
            
            // Increased base size from 0.025 to 0.040, and multiplied by user scale
            let scale = processable.customInPhotoWatermarkScale ?? state.inPhotoWatermarkScale
            let targetHeight = max(width, height) * 0.040 * scale
            let targetWidth = targetHeight * wmAspect
            
            let position = processable.customWatermarkPosition ?? state.defaultWatermarkPosition
            
            var xPos: CGFloat = 0
            let yPos = photoRect.minY + safeMargin
            
            if position == .bottomRight {
                // Align right edge with the frame watermark's right edge
                // Make sure it doesn't cross photo bounds
                xPos = min(frameWmRightX - targetWidth, photoRect.maxX - safeMargin - targetWidth)
            } else {
                // Align left with the same margin
                xPos = photoRect.minX + safeMargin
            }
            
            let wmRect = CGRect(x: xPos, y: yPos, width: targetWidth, height: targetHeight)
            
            let opacity = processable.customInPhotoWatermarkOpacity ?? state.inPhotoWatermarkOpacity
            context.setAlpha(CGFloat(opacity))
            context.draw(inPhotoWmCG, in: wmRect)
        }
        
        guard let finalCGImage = context.makeImage() else { return nil }
        return NSImage(cgImage: finalCGImage, size: NSSize(width: totalWidth, height: totalHeight))
    }
    
    private func loadFrameWatermark(processable: ProcessedImage, state: AppState) -> CGImage? {
        let baseTheme = processable.customThemeColor ?? state.themeColor
        let defaultWmTheme: WatermarkTheme = baseTheme == .black ? .light : .dark
        let wmTheme = processable.customFrameWatermarkTheme ?? defaultWmTheme
        
        let customURL = wmTheme == .light ? state.customFrameLightURL : state.customFrameDarkURL
        if let url = customURL, let img = NSImage(contentsOf: url) {
            return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        
        let name = wmTheme == .light ? defaultFrameWmWhite : defaultFrameWmBlack
        if let img = NSImage(named: name) ?? NSImage(contentsOfFile: Bundle.main.path(forResource: name, ofType: "png") ?? "") {
            return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        return nil
    }
    
    private func loadInPhotoWatermark(processable: ProcessedImage, state: AppState) -> CGImage? {
        let baseTheme = processable.customThemeColor ?? state.themeColor
        let defaultWmTheme: WatermarkTheme = baseTheme == .black ? .light : .dark
        let wmTheme = processable.customInPhotoWatermarkTheme ?? defaultWmTheme
        
        let customURL = wmTheme == .light ? state.customInPhotoLightURL : state.customInPhotoDarkURL
        if let url = customURL, let img = NSImage(contentsOf: url) {
            return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        
        let name = wmTheme == .light ? defaultInPhotoWmWhite : defaultInPhotoWmBlack
        if let img = NSImage(named: name) ?? NSImage(contentsOfFile: Bundle.main.path(forResource: name, ofType: "png") ?? "") {
            return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        return nil
    }
}
