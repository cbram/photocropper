//
//  BatchImageListView.swift
//  PhotoCropper
//
//  Zeigt Liste der Bilder mit Thumbnails für Batch-Verarbeitung
//

import SwiftUI

struct BatchImageListView: View {
    @ObservedObject var batchManager: BatchImageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("BILDER")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(batchManager.readyCount)/\(batchManager.images.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            // Image List
            if batchManager.images.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Keine Bilder geladen")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Text("Ziehen Sie Bilder hier hinein")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(batchManager.images.enumerated()), id: \.element.id) { index, item in
                            BatchImageListItemView(
                                item: item,
                                index: index,
                                isSelected: index == batchManager.currentIndex,
                                onSelect: {
                                    batchManager.selectImage(at: index)
                                },
                                onRemove: {
                                    batchManager.removeImage(at: index)
                                }
                            )
                        }
                    }
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    // Clear all
                    batchManager.clear()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Alle löschen")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .disabled(batchManager.images.isEmpty)
                
                Spacer()
                
                Button(action: {
                    batchManager.previousImage()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(batchManager.currentIndex == 0)
                
                Button(action: {
                    batchManager.nextImage()
                }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(batchManager.currentIndex >= batchManager.images.count - 1)
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
        }
        .frame(width: 250)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct BatchImageListItemView: View {
    @ObservedObject var item: BatchImageItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status Icon
            Image(systemName: item.statusIcon)
                .foregroundColor(item.statusColor)
                .font(.caption)
                .frame(width: 16)
            
            // Thumbnail
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .cornerRadius(4)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(index + 1)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(item.imageData.url.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text("\(Int(item.imageData.pixelSize.width))×\(Int(item.imageData.pixelSize.height))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let ratio = item.cropSettings?.targetRatio {
                    Text("→ \(ratio.id)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Remove Button (on hover)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.2) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    // Dummy Preview
    let manager = BatchImageManager()
    return BatchImageListView(batchManager: manager)
}

