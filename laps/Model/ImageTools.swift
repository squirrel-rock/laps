import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Image work for the photo collection. Everything here runs off the main thread.
enum ImageTools {
    /// The kept source copy: big enough to re-crop well, far smaller than the original.
    static let sourceMaxPixels = 2400
    /// The finished 4:5 picture.
    static let pictureSize = CGSize(width: 1600, height: 2000)
    static let thumbSize = CGSize(width: 320, height: 400)

    /// Reads any photo (HEIC, JPEG, PNG…), turned upright and scaled down to `maxPixels` on its long side.
    static func downsample(_ data: Data, maxPixels: Int = sourceMaxPixels) -> CGImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // applies the camera's rotation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions)
    }

    /// Draws the cropped part of `image` into a canvas of `size`.
    static func render(_ image: CGImage, crop: CropRect, size: CGSize) -> UIImage {
        let iw = Double(image.width), ih = Double(image.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // Scale the whole image so the crop area fills the canvas, then shift it into place.
            let sx = size.width / (crop.width * iw), sy = size.height / (crop.height * ih)
            let rect = CGRect(x: -crop.x * iw * sx, y: -crop.y * ih * sy, width: iw * sx, height: ih * sy)
            UIImage(cgImage: image).draw(in: rect)
        }
    }

    static func jpeg(_ image: CGImage, quality: Double = 0.85) -> Data? {
        UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }

    static func load(_ url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return downsample(data, maxPixels: 4000)
    }
}
