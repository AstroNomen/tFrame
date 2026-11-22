import SwiftUI

struct FilmstripView: View {
    @ObservedObject var appState: AppState
    var onAddPhotos: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 8) {
                // Header / Quick Controls
                HStack(spacing: 6) {
                    Button(action: onAddPhotos) {
                        Label(L10n.t(.addPhotos, lang: appState.currentLanguage), systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !appState.images.isEmpty {
                        Button {
                            appState.clearAll()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help(L10n.t(.clearAll, lang: appState.currentLanguage))
                    }
                }
                .padding(.leading, 12)
                
                Divider()
                    .frame(height: 24)
                
                // Filmstrip Scroll Area
                if appState.images.isEmpty {
                    HStack {
                        Spacer()
                        Text(L10n.t(.dragDropHint, lang: appState.currentLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(Array(appState.images.enumerated()), id: \.element.id) { index, img in
                                    FilmstripItemCard(
                                        index: index + 1,
                                        image: img,
                                        isSelected: appState.selectedImageID == img.id,
                                        onSelect: {
                                            appState.selectedImageID = img.id
                                        },
                                        onDelete: {
                                            appState.removeImage(id: img.id)
                                        },
                                        deleteTitle: L10n.t(.delete, lang: appState.currentLanguage)
                                    )
                                    .id(img.id)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                        .onChange(of: appState.selectedImageID) { newID in
                            if let id = newID {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                
                // Photo Navigator Controls
                if appState.images.count > 1 {
                    Divider()
                        .frame(height: 24)
                    
                    HStack(spacing: 2) {
                        Button {
                            appState.selectPreviousImage()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(appState.selectedImageIndex == 0)
                        .help(L10n.t(.prevPhoto, lang: appState.currentLanguage))
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        
                        if let cur = appState.selectedImageIndex {
                            Text("\(cur + 1)/\(appState.images.count)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            appState.selectNextImage()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(appState.selectedImageIndex == appState.images.count - 1)
                        .help(L10n.t(.nextPhoto, lang: appState.currentLanguage))
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    }
                    .padding(.trailing, 10)
                }
            }
            .frame(height: 84)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct FilmstripItemCard: View {
    let index: Int
    let image: ProcessedImage
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let deleteTitle: String
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    ZStack(alignment: .bottomLeading) {
                        Image(nsImage: image.originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 48)
                            .clipped()
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
                            )
                        
                        // Index badge
                        Text("\(index)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3))
                            .padding(2)
                    }
                    
                    Text(image.originalURL.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 64)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.gray.opacity(0.08) : Color.clear))
                )
                
                // Delete button on hover
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label(deleteTitle, systemImage: "trash")
            }
        }
    }
}
