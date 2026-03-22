import SwiftUI
import UIKit

private final class ZettelImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct S3ZettelImageView: View {
    let key: String
    let cornerRadius: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    private let service = ZettelS3Service()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                    ProgressView()
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.06))

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
