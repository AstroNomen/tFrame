import Cocoa
import CoreGraphics
import ImageIO
import CoreImage

@MainActor
final class ImageProcessor {
    static let shared = ImageProcessor()
    
    // Default watermark names
    private let defaultFrameWmBlack = "TimeSlice_GalleryLabel_Web"
    private let defaultFrameWmWhite = "TimeSlice_GalleryLabel_Web_W"
    private let defaultInPhotoWmBlack = "TimeSlice_BK"
    private let defaultInPhotoWmWhite = "TimeSlice_W"
    
    func process(image processable: ProcessedImage, state: AppState) async -> NSImage? {
        guard let finalCGImage = await processCGImage(image: processable, state: state) else {
            return nil
        }
        return NSImage(cgImage: finalCGImage, size: NSSize(width: finalCGImage.width, height: finalCGImage.height))
    }
    
    func processCGImage(image processable: ProcessedImage, state: AppState) async -> CGImage? {
        guard let cgImage = loadOriginalCGImage(processable: processable) else {
            return nil
        }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Calculate frame width based on user percentage, rounded to integer pixels to avoid subpixel blur
        let frameThickness = round((width + height) * CGFloat(state.frameWidthPercentage / 100.0))
        let style = processable.customFrameStyle ?? state.defaultFrameStyle
        
        let frameLeftRight = style == .cinematic ? 0.0 : frameThickness
        let frameTopBottom = frameThickness
        
        let totalWidth = width + frameLeftRight * 2
        let totalHeight = height + frameTopBottom * 2
        
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
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
        
        // Draw original photo at 1:1 pixel exact bounds
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
            
            context.saveGState()
            context.setAlpha(CGFloat(state.frameWatermarkOpacity))
            context.draw(frameWmCG, in: wmRect)
            context.restoreGState()
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
            context.saveGState()
            context.setAlpha(CGFloat(opacity))
            context.draw(inPhotoWmCG, in: wmRect)
            context.restoreGState()
        }
        
        return context.makeImage()
    }
    
    private func loadOriginalCGImage(processable: ProcessedImage) -> CGImage? {
        let options = [kCGImageSourceShouldCache: true] as CFDictionary
        if let source = CGImageSourceCreateWithURL(processable.originalURL as CFURL, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) {
            
            // Check orientation from metadata and apply if needed
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let orientationNum = properties[kCGImagePropertyOrientation] as? UInt32,
               let orientation = CGImagePropertyOrientation(rawValue: orientationNum),
               orientation != .up {
                let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
                let ciContext = CIContext()
                if let orientedCG = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                    return orientedCG
                }
            }
            return cgImage
        }
        
        // Fallback to processable.originalImage
        if let rep = processable.originalImage.representations.first(where: { $0 is NSBitmapImageRep }) as? NSBitmapImageRep,
           let cg = rep.cgImage {
            return cg
        }
        
        var rect = CGRect(origin: .zero, size: processable.originalImage.size)
        return processable.originalImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    
    private func loadFrameWatermark(processable: ProcessedImage, state: AppState) -> CGImage? {
        let baseTheme = processable.customThemeColor ?? state.themeColor
        let defaultWmTheme: WatermarkTheme = baseTheme == .black ? .light : .dark
        let wmTheme = processable.customFrameWatermarkTheme ?? defaultWmTheme
        
        let customURL = wmTheme == .light ? state.customFrameLightURL : state.customFrameDarkURL
        if let url = customURL {
            return loadCGImage(from: url)
        }
        
        let name = wmTheme == .light ? defaultFrameWmWhite : defaultFrameWmBlack
        return loadCGImage(named: name)
    }
    
    private func loadInPhotoWatermark(processable: ProcessedImage, state: AppState) -> CGImage? {
        let baseTheme = processable.customThemeColor ?? state.themeColor
        let defaultWmTheme: WatermarkTheme = baseTheme == .black ? .light : .dark
        let wmTheme = processable.customInPhotoWatermarkTheme ?? defaultWmTheme
        
        let customURL = wmTheme == .light ? state.customInPhotoLightURL : state.customInPhotoDarkURL
        if let url = customURL {
            return loadCGImage(from: url)
        }
        
        let name = wmTheme == .light ? defaultInPhotoWmWhite : defaultInPhotoWmBlack
        return loadCGImage(named: name)
    }
    
    private func loadCGImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [kCGImageSourceShouldCache: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
    
    private func loadCGImage(named name: String) -> CGImage? {
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            return loadCGImage(from: URL(fileURLWithPath: path))
        }
        if let img = NSImage(named: name) {
            if let rep = img.representations.first(where: { $0 is NSBitmapImageRep }) as? NSBitmapImageRep,
               let cg = rep.cgImage {
                return cg
            }
            var rect = CGRect(origin: .zero, size: img.size)
            return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return nil
    }
}
