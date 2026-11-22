import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

enum ExportQuality: String, CaseIterable, Identifiable {
    case lossless = "lossless"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var id: String { rawValue }
    
    var compressionFactor: Double {
        switch self {
        case .lossless: return 1.0
        case .high: return 0.92
        case .medium: return 0.80
        case .low: return 0.65
        }
    }
    
    var percentage: Int {
        switch self {
        case .lossless: return 100
        case .high: return 92
        case .medium: return 80
        case .low: return 65
        }
    }
    
    func title(for lang: AppLanguage) -> String {
        switch lang {
        case .zh:
            switch self {
            case .lossless: return "无损 (100%)"
            case .high: return "高画质 (92%)"
            case .medium: return "中等画质 (80%)"
            case .low: return "轻巧画质 (65%)"
            }
        case .en:
            switch self {
            case .lossless: return "Lossless (100%)"
            case .high: return "High (92%)"
            case .medium: return "Medium (80%)"
            case .low: return "Low (65%)"
            }
        }
    }
    
    func subtitle(for lang: AppLanguage) -> String {
        switch lang {
        case .zh:
            switch self {
            case .lossless: return "完全不压缩，保留最原始细节，文件体积最大"
            case .high: return "视觉完全无损，接近无损画质且体积大幅缩减，推荐摄影交付"
            case .medium: return "画质与体积兼备，细节保留良好，适合网页展示与网络分享"
            case .low: return "高压缩率，体积轻巧紧凑，适合快速预览或邮件发送"
            }
        case .en:
            switch self {
            case .lossless: return "No compression, retains raw detail, largest file size"
            case .high: return "Visually lossless, optimal balance for photography delivery"
            case .medium: return "Balanced quality & size, ideal for web and social media"
            case .low: return "Higher compression, lightweight, perfect for email and quick sharing"
            }
        }
    }
}

struct L10n {
    static func t(_ key: Key, lang: AppLanguage) -> String {
        switch lang {
        case .zh: return key.zh
        case .en: return key.en
        }
    }
    
    enum Key {
        // App / Navigation Tabs
        case appName
        case tabFrameWatermark
        case tabCollage
        case comingSoon
        case collagePlaceholderTitle
        case collagePlaceholderSubtitle
        
        // Filmstrip / Photos
        case filmstripTitle
        case addPhotos
        case clearAll
        case delete
        case dragDropHint
        case processingPreview
        case noPhotoSelected
        case prevPhoto
        case nextPhoto
        
        // Toolbar
        case exportSelected
        case exportAll
        case selectExportFolder
        case exportPhotoTitle
        case exportPhotoMessage
        case exportFolderTitle
        case exportFolderPrompt
        
        // Settings
        case settings
        case generalSettings
        case exportSettingsTab
        case language
        case defaultExportQuality
        case qualityDescription
        case done
        
        // Inspector Tabs & Scope
        case scopeThisPhoto
        case scopeGlobal
        case resetToDefaults
        case customizedBadge
        
        // Global Theme & Frame
        case globalTheme
        case themeColor
        case black
        case white
        case frameSettings
        case defaultStyle
        case fullFrame
        case cinematic
        case frameWidth
        case exportQualitySection
        case exportQualityLabel
        case useGlobalDefault
        case estimatedSize
        case estimatedDimensions
        case totalEstimatedSize
        
        // Watermarks
        case watermarkSettings
        case defaultPosition
        case bottomRight
        case bottomLeft
        case inPhotoSize
        case inPhotoOpacity
        case frameSize
        case frameOpacity
        case customWatermarks
        case watermarkNoticeTitle
        case watermarkNoticeBody
        case inPhotoWatermarks
        case frameWatermarks
        case lightWatermarkTitle
        case lightWatermarkSub
        case darkWatermarkTitle
        case darkWatermarkSub
        case light
        case dark
        case none
        case select
        case clear
        case selectWatermarkTitle
        case selectWatermarkMessage
        case selectPrompt
        
        // Overrides
        case overrides
        case auto
        case selectedImage
        case allImagesCount(Int)
        case selectedOfTotal(Int, Int)
        
        var zh: String {
            switch self {
            case .appName: return "tFrame"
            case .tabFrameWatermark: return "边框水印"
            case .tabCollage: return "多图拼图"
            case .comingSoon: return "即将推出"
            case .collagePlaceholderTitle: return "拼图功能即将上线"
            case .collagePlaceholderSubtitle: return "我们正在开发多图拼贴、九宫格排版和故事长图功能，敬请期待。"
            case .filmstripTitle: return "底片胶卷"
            case .addPhotos: return "添加照片"
            case .clearAll: return "清空"
            case .delete: return "删除"
            case .dragDropHint: return "拖拽照片至此处开始处理"
            case .processingPreview: return "正在生成高清预览..."
            case .noPhotoSelected: return "请选择或导入照片"
            case .prevPhoto: return "上一张"
            case .nextPhoto: return "下一张"
            case .exportSelected: return "导出"
            case .exportAll: return "导出全部"
            case .selectExportFolder: return "选择导出文件夹"
            case .exportPhotoTitle: return "导出单张照片"
            case .exportPhotoMessage: return "保存添加边框和水印后的交付照片"
            case .exportFolderTitle: return "选择批量导出保存目录"
            case .exportFolderPrompt: return "导出至此处"
            case .settings: return "设置"
            case .generalSettings: return "常规设置"
            case .exportSettingsTab: return "导出设置"
            case .language: return "显示语言"
            case .defaultExportQuality: return "全局默认导出画质"
            case .qualityDescription: return "画质说明"
            case .done: return "完成"
            case .scopeThisPhoto: return "当前照片"
            case .scopeGlobal: return "全局默认"
            case .resetToDefaults: return "恢复为全局设置"
            case .customizedBadge: return "独立自定义"
            case .globalTheme: return "相框底色"
            case .themeColor: return "相框颜色"
            case .black: return "黑色 (暗底)"
            case .white: return "白色 (亮底)"
            case .frameSettings: return "边框样式"
            case .defaultStyle: return "边框版式"
            case .fullFrame: return "全包边框 (Full)"
            case .cinematic: return "宽银幕上下边 (Cinematic)"
            case .frameWidth: return "边框宽度"
            case .exportQualitySection: return "导出画质"
            case .exportQualityLabel: return "压缩档位"
            case .useGlobalDefault: return "跟随全局设置"
            case .estimatedSize: return "预估体积"
            case .estimatedDimensions: return "导出分辨率"
            case .totalEstimatedSize: return "全部照片预估总计"
            case .watermarkSettings: return "水印布局与透明度"
            case .defaultPosition: return "对齐角标"
            case .bottomRight: return "右下角"
            case .bottomLeft: return "左下角"
            case .inPhotoSize: return "画内水印尺寸"
            case .inPhotoOpacity: return "画内水印透明度"
            case .frameSize: return "边框水印尺寸"
            case .frameOpacity: return "边框水印透明度"
            case .customWatermarks: return "自定义水印素材库"
            case .watermarkNoticeTitle: return "色彩反差匹配原则"
            case .watermarkNoticeBody: return "黑色/暗底相框自动匹配【浅色/白色水印】；白色/亮底相框自动匹配【深色/黑色水印】。支持 PNG, JPG, SVG, PDF, WebP 等格式。"
            case .inPhotoWatermarks: return "相片内水印 (In-Photo)"
            case .frameWatermarks: return "相框边框水印 (Frame)"
            case .lightWatermarkTitle: return "浅色/白色水印"
            case .lightWatermarkSub: return "用于黑色边框或暗色背景"
            case .darkWatermarkTitle: return "深色/黑色水印"
            case .darkWatermarkSub: return "用于白色边框或亮色背景"
            case .light: return "浅色 (白)"
            case .dark: return "深色 (黑)"
            case .none: return "未导入 (使用默认)"
            case .select: return "选择素材"
            case .clear: return "清除"
            case .selectWatermarkTitle: return "选择透明水印文件"
            case .selectWatermarkMessage: return "支持导入 PNG, JPG, SVG, PDF, WebP 等水印文件"
            case .selectPrompt: return "选择文件"
            case .overrides: return "单张独立调整"
            case .auto: return "自动匹配"
            case .selectedImage: return "当前照片"
            case .allImagesCount(let count): return "共 \(count) 张照片"
            case .selectedOfTotal(let cur, let total): return "第 \(cur) / \(total) 张"
            }
        }
        
        var en: String {
            switch self {
            case .appName: return "tFrame"
            case .tabFrameWatermark: return "Frame & Watermark"
            case .tabCollage: return "Collage"
            case .comingSoon: return "Coming Soon"
            case .collagePlaceholderTitle: return "Collage Feature Coming Soon"
            case .collagePlaceholderSubtitle: return "We are crafting multi-photo grids, story layouts, and seamless stitching. Stay tuned!"
            case .filmstripTitle: return "Filmstrip"
            case .addPhotos: return "Add Photos"
            case .clearAll: return "Clear"
            case .delete: return "Delete"
            case .dragDropHint: return "Drag and drop photos here to get started"
            case .processingPreview: return "Generating high-res preview..."
            case .noPhotoSelected: return "No photo selected"
            case .prevPhoto: return "Previous"
            case .nextPhoto: return "Next"
            case .exportSelected: return "Export"
            case .exportAll: return "Export All"
            case .selectExportFolder: return "Select Export Folder"
            case .exportPhotoTitle: return "Export Single Photo"
            case .exportPhotoMessage: return "Save framed and watermarked photo for delivery"
            case .exportFolderTitle: return "Select Batch Export Directory"
            case .exportFolderPrompt: return "Export Here"
            case .settings: return "Settings"
            case .generalSettings: return "General"
            case .exportSettingsTab: return "Export"
            case .language: return "Language"
            case .defaultExportQuality: return "Default Export Quality"
            case .qualityDescription: return "Quality Presets"
            case .done: return "Done"
            case .scopeThisPhoto: return "This Photo"
            case .scopeGlobal: return "Global Defaults"
            case .resetToDefaults: return "Reset to Defaults"
            case .customizedBadge: return "Customized"
            case .globalTheme: return "Frame Color"
            case .themeColor: return "Color"
            case .black: return "Black (Dark)"
            case .white: return "White (Light)"
            case .frameSettings: return "Frame Style"
            case .defaultStyle: return "Border Style"
            case .fullFrame: return "Full Frame"
            case .cinematic: return "Cinematic (Top/Bottom)"
            case .frameWidth: return "Frame Width"
            case .exportQualitySection: return "Export Quality"
            case .exportQualityLabel: return "Quality Preset"
            case .useGlobalDefault: return "Use Global Default"
            case .estimatedSize: return "Estimated Size"
            case .estimatedDimensions: return "Export Dimensions"
            case .totalEstimatedSize: return "Total Estimated"
            case .watermarkSettings: return "Watermark Layout & Opacity"
            case .defaultPosition: return "Corner Position"
            case .bottomRight: return "Bottom Right"
            case .bottomLeft: return "Bottom Left"
            case .inPhotoSize: return "In-Photo Size"
            case .inPhotoOpacity: return "In-Photo Opacity"
            case .frameSize: return "Frame Watermark Size"
            case .frameOpacity: return "Frame Watermark Opacity"
            case .customWatermarks: return "Custom Watermarks Library"
            case .watermarkNoticeTitle: return "Contrast Matching Principle"
            case .watermarkNoticeBody: return "Black/Dark frames automatically pair with [Light/White Watermarks]; White/Light frames automatically pair with [Dark/Black Watermarks]. Supports PNG, JPG, SVG, PDF, WebP formats."
            case .inPhotoWatermarks: return "In-Photo Watermark"
            case .frameWatermarks: return "Frame Watermark"
            case .lightWatermarkTitle: return "Light / White Watermark"
            case .lightWatermarkSub: return "For black borders and dark imagery"
            case .darkWatermarkTitle: return "Dark / Black Watermark"
            case .darkWatermarkSub: return "For white borders and bright imagery"
            case .light: return "Light (White)"
            case .dark: return "Dark (Black)"
            case .none: return "None (Default used)"
            case .select: return "Select File"
            case .clear: return "Clear"
            case .selectWatermarkTitle: return "Select Transparent Watermark"
            case .selectWatermarkMessage: return "Supports PNG, JPG, SVG, PDF, WebP watermark assets"
            case .selectPrompt: return "Select File"
            case .overrides: return "Individual Adjustments"
            case .auto: return "Auto Match"
            case .selectedImage: return "Selected Photo"
            case .allImagesCount(let count): return "\(count) photos in total"
            case .selectedOfTotal(let cur, let total): return "#\(cur) of \(total)"
            }
        }
    }
}
