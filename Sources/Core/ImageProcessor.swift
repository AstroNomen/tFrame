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
        
        let style = processable.customFrameStyle ?? state.defaultFrameStyle
        let cinematicRatio = processable.customCinematicRatio ?? state.defaultCinematicRatio
        let insets = style.insets(width: Double(width), height: Double(height), percentage: state.frameWidthPercentage, cinematicRatio: cinematicRatio)
        
        let frameLeft = CGFloat(insets.left)
        let frameRight = CGFloat(insets.right)
        let frameTop = CGFloat(insets.top)
        let frameBottom = CGFloat(insets.bottom)
        
        let totalWidth = width + frameLeft + frameRight
        let totalHeight = height + frameTop + frameBottom
        
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
        let frameColor: CGColor
        if style == .film {
            frameColor = NSColor.black.cgColor
        } else {
            frameColor = theme == .black ? NSColor.black.cgColor : NSColor.white.cgColor
        }
        context.setFillColor(frameColor)
        context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        
        // Draw original photo at 1:1 pixel exact bounds
        let photoRect = CGRect(x: frameLeft, y: frameBottom, width: width, height: height)
        context.draw(cgImage, in: photoRect)
        
        // Draw style-specific features (Stamp perforations or Film sprockets)
        if style == .stamp {
            drawStampPerforations(context: context, totalWidth: totalWidth, totalHeight: totalHeight, border: frameLeft)
        } else if style == .film {
            drawFilmSprockets(context: context, totalWidth: totalWidth, totalHeight: totalHeight, frameLeft: frameLeft, frameRight: frameRight, frameTop: frameTop, frameBottom: frameBottom)
        }
        
        // Safe margin from the photo's edge
        // If has bottom frame, scale with frame thickness; if 0 frame (borderless), use 3% of min dimension
        let safeMargin: CGFloat
        if style == .polaroid {
            safeMargin = max(frameLeft * 0.6, min(width, height) * 0.025)
        } else if style == .square {
            safeMargin = max(frameBottom * 0.25, min(width, height) * 0.03)
        } else if style == .sideLabelLeft || style == .sideLabelRight {
            safeMargin = min(width, height) * 0.03
        } else if frameBottom > 0 {
            safeMargin = max(frameBottom * 0.35, min(width, height) * 0.02)
        } else {
            safeMargin = min(width, height) * 0.03
        }
        
        // 1. Draw Frame Watermark
        var frameWmRightX: CGFloat = 0
        if let frameWmCG = loadFrameWatermark(processable: processable, state: state) {
            let wmAspect = CGFloat(frameWmCG.width) / CGFloat(frameWmCG.height)
            let scale = processable.customFrameWatermarkScale ?? state.frameWatermarkScale
            
            if style == .sideLabelLeft || style == .sideLabelRight {
                // 侧边栏：竖向旋转 90° 居中在侧栏
                let sideWidth = style == .sideLabelLeft ? frameLeft : frameRight
                let targetHeight = sideWidth * 0.35 * scale
                let targetWidth = targetHeight * wmAspect
                let centerX = style == .sideLabelLeft ? (frameLeft / 2.0) : (photoRect.maxX + frameRight / 2.0)
                let centerY = totalHeight / 2.0
                
                context.saveGState()
                context.setAlpha(CGFloat(state.frameWatermarkOpacity))
                context.translateBy(x: centerX, y: centerY)
                context.rotate(by: CGFloat.pi / 2.0)
                context.draw(frameWmCG, in: CGRect(x: -targetWidth / 2.0, y: -targetHeight / 2.0, width: targetWidth, height: targetHeight))
                context.restoreGState()
                
                frameWmRightX = photoRect.maxX - safeMargin
            } else if frameBottom > 0 && style != .film {
                let baseHeight = (style == .square || style == .cinematic) ? min(frameBottom * 0.35, min(width, height) * 0.045) : (frameBottom * 0.35)
                let targetHeight = baseHeight * scale
                let targetWidth = targetHeight * wmAspect
                
                // Centered vertically in the bottom border
                let yPos = (frameBottom - targetHeight) / 2.0
                
                // Placed on the right, with a safe margin from the photo's right edge
                let xPos = photoRect.maxX - safeMargin - targetWidth
                frameWmRightX = xPos + targetWidth
                
                let wmRect = CGRect(x: xPos, y: yPos, width: targetWidth, height: targetHeight)
                
                context.saveGState()
                context.setAlpha(CGFloat(state.frameWatermarkOpacity))
                context.draw(frameWmCG, in: wmRect)
                context.restoreGState()
            } else {
                frameWmRightX = photoRect.maxX - safeMargin
            }
        } else {
            // Default right boundary for alignment if no frame or no frame watermark
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
        let style = processable.customFrameStyle ?? state.defaultFrameStyle
        let baseTheme = processable.customThemeColor ?? state.themeColor
        let defaultWmTheme: WatermarkTheme = (style == .film) ? .light : (baseTheme == .black ? .light : .dark)
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
        let pathExt = url.pathExtension.lowercased()
        
        // 1. Direct raster image formats via CGImageSource (PNG, JPG, WebP, TIFF, HEIC, etc.)
        if ["png", "jpg", "jpeg", "webp", "tiff", "tif", "heic", "bmp"].contains(pathExt) {
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
                let options = [kCGImageSourceShouldCache: true] as CFDictionary
                if let cg = CGImageSourceCreateImageAtIndex(source, 0, options) {
                    return cg
                }
            }
        }
        
        // 2. Vector formats (SVG, PDF) or other formats rendered via NSImage at high fidelity
        if let nsImage = NSImage(contentsOf: url) {
            let naturalSize = nsImage.size
            guard naturalSize.width > 0, naturalSize.height > 0 else { return nil }
            
            // Render vector assets at crisp high resolution (at least 2400px wide/high)
            let maxDimension: CGFloat = max(naturalSize.width, naturalSize.height)
            let renderScale: CGFloat = maxDimension < 2400 ? (2400 / maxDimension) : 1.0
            let renderWidth = max(Int(naturalSize.width * renderScale), 100)
            let renderHeight = max(Int(naturalSize.height * renderScale), 100)
            
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            
            if let context = CGContext(data: nil,
                                       width: renderWidth,
                                       height: renderHeight,
                                       bitsPerComponent: 8,
                                       bytesPerRow: 0,
                                       space: colorSpace,
                                       bitmapInfo: bitmapInfo) {
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = nsContext
                
                nsImage.draw(in: CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight),
                             from: .zero,
                             operation: .copy,
                             fraction: 1.0)
                
                NSGraphicsContext.restoreGraphicsState()
                return context.makeImage()
            }
        }
        return nil
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
    
    // MARK: - Specialized Frame Drawing
    
    private func drawFilmSprockets(context: CGContext, totalWidth: CGFloat, totalHeight: CGFloat, frameLeft: CGFloat, frameRight: CGFloat, frameTop: CGFloat, frameBottom: CGFloat) {
        context.saveGState()
        
        if frameTop > 0 && frameBottom > 0 {
            // 横向胶卷：齿孔在【上下两排】横向排列
            let holeHeight = round(frameBottom * 0.48)
            let holeWidth = round(holeHeight * (1.98 / 2.79))
            let holePitch = round(holeHeight * (4.75 / 2.79))
            let cornerRadius = round(holeWidth * 0.22)
            
            let totalHoles = Int(ceil(totalWidth / holePitch)) + 2
            let totalSpan = CGFloat(totalHoles - 1) * holePitch + holeWidth
            let startX = (totalWidth - totalSpan) / 2.0
            
            let bottomY = (frameBottom - holeHeight) / 2.0
            let topY = totalHeight - frameTop + (frameTop - holeHeight) / 2.0
            
            for i in 0..<totalHoles {
                let x = startX + CGFloat(i) * holePitch
                let bottomHoleRect = CGRect(x: x, y: bottomY, width: holeWidth, height: holeHeight)
                let topHoleRect = CGRect(x: x, y: topY, width: holeWidth, height: holeHeight)
                
                // 下排齿孔
                let bottomPath = CGPath(roundedRect: bottomHoleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.setBlendMode(.clear)
                context.addPath(bottomPath)
                context.fillPath()
                
                context.setBlendMode(.normal)
                context.setStrokeColor(NSColor(white: 0.28, alpha: 0.8).cgColor)
                context.setLineWidth(1.0)
                context.addPath(bottomPath)
                context.strokePath()
                
                // 上排齿孔
                let topPath = CGPath(roundedRect: topHoleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.setBlendMode(.clear)
                context.addPath(topPath)
                context.fillPath()
                
                context.setBlendMode(.normal)
                context.setStrokeColor(NSColor(white: 0.28, alpha: 0.8).cgColor)
                context.setLineWidth(1.0)
                context.addPath(topPath)
                context.strokePath()
            }
        } else if frameLeft > 0 && frameRight > 0 {
            // 竖向胶卷（相机旋转90°竖构图）：齿孔在【左右两排】纵向排列
            let holeWidth = round(frameLeft * 0.48)
            let holeHeight = round(holeWidth * (2.79 / 1.98))
            let holePitch = round(holeWidth * (4.75 / 1.98))
            let cornerRadius = round(holeWidth * 0.22)
            
            let totalHoles = Int(ceil(totalHeight / holePitch)) + 2
            let totalSpan = CGFloat(totalHoles - 1) * holePitch + holeHeight
            let startY = (totalHeight - totalSpan) / 2.0
            
            let leftX = (frameLeft - holeWidth) / 2.0
            let rightX = totalWidth - frameRight + (frameRight - holeWidth) / 2.0
            
            for i in 0..<totalHoles {
                let y = startY + CGFloat(i) * holePitch
                let leftHoleRect = CGRect(x: leftX, y: y, width: holeWidth, height: holeHeight)
                let rightHoleRect = CGRect(x: rightX, y: y, width: holeWidth, height: holeHeight)
                
                // 左排齿孔
                let leftPath = CGPath(roundedRect: leftHoleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.setBlendMode(.clear)
                context.addPath(leftPath)
                context.fillPath()
                
                context.setBlendMode(.normal)
                context.setStrokeColor(NSColor(white: 0.28, alpha: 0.8).cgColor)
                context.setLineWidth(1.0)
                context.addPath(leftPath)
                context.strokePath()
                
                // 右排齿孔
                let rightPath = CGPath(roundedRect: rightHoleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.setBlendMode(.clear)
                context.addPath(rightPath)
                context.fillPath()
                
                context.setBlendMode(.normal)
                context.setStrokeColor(NSColor(white: 0.28, alpha: 0.8).cgColor)
                context.setLineWidth(1.0)
                context.addPath(rightPath)
                context.strokePath()
            }
        }
        
        context.restoreGState()
    }
    
    private func drawStampPerforations(context: CGContext, totalWidth: CGFloat, totalHeight: CGFloat, border: CGFloat) {
        let radius = max(round(border * 0.28), 8.0)
        let pitch = radius * 2.6
        
        context.saveGState()
        context.setBlendMode(.clear)
        
        // 顶部与底部边缘打孔
        let countX = max(Int(round(totalWidth / pitch)), 2)
        let stepX = totalWidth / CGFloat(countX)
        for i in 0...countX {
            let cx = CGFloat(i) * stepX
            context.fillEllipse(in: CGRect(x: cx - radius, y: -radius, width: radius * 2, height: radius * 2))
            context.fillEllipse(in: CGRect(x: cx - radius, y: totalHeight - radius, width: radius * 2, height: radius * 2))
        }
        
        // 左侧与右侧边缘打孔
        let countY = max(Int(round(totalHeight / pitch)), 2)
        let stepY = totalHeight / CGFloat(countY)
        for i in 0...countY {
            let cy = CGFloat(i) * stepY
            context.fillEllipse(in: CGRect(x: -radius, y: cy - radius, width: radius * 2, height: radius * 2))
            context.fillEllipse(in: CGRect(x: totalWidth - radius, y: cy - radius, width: radius * 2, height: radius * 2))
        }
        
        context.restoreGState()
    }
}
