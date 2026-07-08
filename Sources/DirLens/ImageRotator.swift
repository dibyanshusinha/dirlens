import CoreGraphics
import Foundation
import ImageIO

/// Physically rotates an image file on disk, in place.
///
/// JPEG/TIFF are rotated by patching just the 2 bytes of the EXIF
/// Orientation tag directly in the file's existing bytes — no decode, no
/// re-encode, so it's instant and truly lossless (byte-identical otherwise).
/// `CGImageDestinationAddImageFromSource` looks like it should offer the same
/// thing, but in practice it re-encodes with ImageIO's own default quality/
/// chroma subsampling, which can noticeably shrink (or grow) high-quality
/// source files — so it's only used as a fallback when a file has no EXIF
/// orientation tag to patch, and always for HEIC (no byte-level patcher for
/// that container format here). Formats without a reliable orientation
/// convention (PNG, GIF, BMP, ...) are rotated by redrawing the pixels into
/// a rotated canvas and re-encoding; since those are lossless formats to
/// begin with, that doesn't lose quality either.
enum ImageRotator {
    private static let orientationAwareTypes: Set<String> = [
        "public.jpeg", "public.tiff", "public.heic", "public.heif"
    ]
    private static let bytePatchableTypes: Set<String> = ["public.jpeg", "public.tiff"]

    static func rotate(fileAt url: URL, byDegrees delta: Int) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String? else {
            return false
        }

        if orientationAwareTypes.contains(type) {
            if bytePatchableTypes.contains(type),
               rotateViaBytePatch(source: source, type: type, url: url, delta: delta) {
                return true
            }
            return rotateViaMetadataReencode(source: source, type: type as CFString, url: url, delta: delta)
        }
        return rotateViaPixels(source: source, type: type as CFString, url: url, delta: delta)
    }

    // MARK: - True lossless rotation via direct byte patch (JPEG/TIFF)

    private static func rotateViaBytePatch(source: CGImageSource, type: String, url: URL, delta: Int) -> Bool {
        guard var data = try? Data(contentsOf: url) else { return false }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let currentRaw = (properties?[kCGImagePropertyOrientation] as? Int) ?? 1
        let currentDegrees = degrees(forExifOrientation: currentRaw)
        let newDegrees = normalize(currentDegrees + delta)
        let newOrientation = UInt16(exifOrientation(forDegrees: newDegrees))

        let patched = type == "public.jpeg"
            ? JPEGOrientationPatcher.patchJPEG(&data, newOrientation: newOrientation)
            : JPEGOrientationPatcher.patchTIFF(&data, newOrientation: newOrientation)
        guard patched else { return false }

        return writeAtomically(to: url) { tempURL in
            try? data.write(to: tempURL, options: .atomic)
            return FileManager.default.fileExists(atPath: tempURL.path)
        }
    }

    // MARK: - Metadata rotation with a full re-encode (fallback + HEIC)

    private static func rotateViaMetadataReencode(source: CGImageSource, type: CFString, url: URL, delta: Int) -> Bool {
        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        let currentRaw = (properties[kCGImagePropertyOrientation] as? Int) ?? 1
        let currentDegrees = degrees(forExifOrientation: currentRaw)
        let newDegrees = normalize(currentDegrees + delta)
        properties[kCGImagePropertyOrientation] = exifOrientation(forDegrees: newDegrees)
        properties[kCGImageDestinationLossyCompressionQuality] = 0.92

        return writeAtomically(to: url) { tempURL in
            guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil) else { return false }
            CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
            return CGImageDestinationFinalize(destination)
        }
    }

    private static func degrees(forExifOrientation orientation: Int) -> Int {
        switch orientation {
        case 1: return 0
        case 6: return 90
        case 3: return 180
        case 8: return 270
        default: return 0 // 2,4,5,7 involve mirroring; we never produce those ourselves.
        }
    }

    private static func exifOrientation(forDegrees degrees: Int) -> Int {
        switch normalize(degrees) {
        case 90: return 6
        case 180: return 3
        case 270: return 8
        default: return 1
        }
    }

    // MARK: - Lossless pixel rotation (PNG/GIF/BMP/etc.)

    private static func rotateViaPixels(source: CGImageSource, type: CFString, url: URL, delta: Int) -> Bool {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }

        // Negated: CGContext's default (y-up) coordinate space treats positive
        // angles as counter-clockwise, but our convention (matching the EXIF
        // orientation path) is that positive `delta` means clockwise ("rotate right").
        let radians = -CGFloat(normalize(delta)) * .pi / 180
        let swaps = normalize(delta) == 90 || normalize(delta) == 270
        let width = cgImage.width
        let height = cgImage.height
        let newWidth = swaps ? height : width
        let newHeight = swaps ? width : height

        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return false
        }

        context.translateBy(x: CGFloat(newWidth) / 2, y: CGFloat(newHeight) / 2)
        context.rotate(by: radians)
        context.draw(cgImage, in: CGRect(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2, width: CGFloat(width), height: CGFloat(height)))

        guard let rotatedImage = context.makeImage() else { return false }
        let properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]

        return writeAtomically(to: url) { tempURL in
            guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil) else { return false }
            CGImageDestinationAddImage(destination, rotatedImage, properties as CFDictionary)
            return CGImageDestinationFinalize(destination)
        }
    }

    // MARK: - Shared helpers

    private static func normalize(_ degrees: Int) -> Int {
        ((degrees % 360) + 360) % 360
    }

    /// Writes to a temp file in the same directory (so the final replace is
    /// an atomic same-volume rename), then swaps it in for the original.
    private static func writeAtomically(to url: URL, write: (URL) -> Bool) -> Bool {
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".dirlens-rotate-\(UUID().uuidString)")

        guard write(tempURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }

        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            return true
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }
}
