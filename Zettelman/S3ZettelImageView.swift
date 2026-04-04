import SwiftUI
import UIKit

private final class ZettelImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct S3ZettelImageView: View {
    let key: String
    let cornerRadius: CGFloat
    let contentMode: ContentMode

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    private let service = ZettelS3Service()

    init(key: String, cornerRadius: CGFloat, contentMode: ContentMode = .fill) {
        self.key = key
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(loadingPlaceholderFillColor)
                    ProgressView()
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(emptyPlaceholderFillColor)

                    VStack(spacing: 8) {
                        Image(systemName: loadFailed ? "exclamationmark.triangle" : "doc.text.image")
                            .font(.title3)
                        Text(loadFailed ? "Image unavailable" : "No image")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: key) {
            await loadIfNeeded()
        }
    }

    private var loadingPlaceholderFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05)
    }

    private var emptyPlaceholderFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    @MainActor
    private func loadIfNeeded() async {
        if let cached = ZettelImageCache.shared.object(forKey: key as NSString) {
            image = cached
            return
        }

        isLoading = true
        loadFailed = false

        do {
            let data = try await service.downloadZettelData(for: key)
            guard let loadedImage = UIImage(data: data) else {
                throw ZettelmanError.invalidImage
            }

            ZettelImageCache.shared.setObject(loadedImage, forKey: key as NSString)
            image = loadedImage
        } catch {
            loadFailed = true
        }

        isLoading = false
    }
}
