import Foundation

/// Rewrites just the EXIF Orientation tag's 2 value bytes directly in a JPEG
/// or TIFF file's existing bytes — no decode, no re-encode, no pixel touched.
/// ImageIO's `CGImageDestinationAddImageFromSource` looks lossless on paper
/// but in practice re-encodes (different quality/chroma subsampling than the
/// original), which can multiply a photo's file size down noticeably. This
/// sidesteps that entirely by patching the file's own bytes in place.
enum JPEGOrientationPatcher {
    /// Attempts to patch the orientation tag in a raw TIFF file's bytes.
    static func patchTIFF(_ data: inout Data, newOrientation: UInt16) -> Bool {
        patchTIFFDirectory(&data, tiffStart: 0, newOrientation: newOrientation)
    }

    /// Attempts to patch the orientation tag inside a JPEG's embedded EXIF
    /// (APP1) segment. Returns false if no EXIF/orientation tag is present —
    /// callers should fall back to a full re-encode in that case.
    static func patchJPEG(_ data: inout Data, newOrientation: UInt16) -> Bool {
        guard data.count > 4, data[0] == 0xFF, data[1] == 0xD8 else { return false }

        var offset = 2
        while offset + 4 <= data.count {
            guard data[offset] == 0xFF else { return false }
            let marker = data[offset + 1]
            // SOS: the compressed scan data follows: no more header segments.
            if marker == 0xDA || marker == 0xD9 { return false }
            // Standalone markers (no length field).
            if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7) {
                offset += 2
                continue
            }

            let length = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            guard length >= 2, offset + 2 + length <= data.count else { return false }
            let payloadStart = offset + 4

            if marker == 0xE1, payloadStart + 6 <= data.count {
                let signature = data[payloadStart..<payloadStart + 6]
                if signature.elementsEqual([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]) { // "Exif\0\0"
                    let tiffStart = payloadStart + 6
                    if patchTIFFDirectory(&data, tiffStart: tiffStart, newOrientation: newOrientation) {
                        return true
                    }
                }
            }

            offset += 2 + length
        }
        return false
    }

    // MARK: - TIFF IFD0 orientation patch

    private static func patchTIFFDirectory(_ data: inout Data, tiffStart: Int, newOrientation: UInt16) -> Bool {
        guard tiffStart + 8 <= data.count else { return false }

        let bigEndian: Bool
        if data[tiffStart] == 0x49, data[tiffStart + 1] == 0x49 { // "II"
            bigEndian = false
        } else if data[tiffStart] == 0x4D, data[tiffStart + 1] == 0x4D { // "MM"
            bigEndian = true
        } else {
            return false
        }

        func read16(_ at: Int) -> Int? {
            guard at + 2 <= data.count else { return nil }
            let b0 = Int(data[at]), b1 = Int(data[at + 1])
            return bigEndian ? (b0 << 8 | b1) : (b1 << 8 | b0)
        }
        func read32(_ at: Int) -> Int? {
            guard at + 4 <= data.count else { return nil }
            let b = (0..<4).map { Int(data[at + $0]) }
            return bigEndian
                ? (b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3])
                : (b[3] << 24 | b[2] << 16 | b[1] << 8 | b[0])
        }

        guard let magic = read16(tiffStart + 2), magic == 42,
              let ifd0Relative = read32(tiffStart + 4) else {
            return false
        }

        let ifd0Offset = tiffStart + ifd0Relative
        guard let entryCount = read16(ifd0Offset) else { return false }

        for i in 0..<entryCount {
            let entryOffset = ifd0Offset + 2 + i * 12
            guard let tag = read16(entryOffset) else { return false }
            if tag == 0x0112 { // Orientation
                let valueOffset = entryOffset + 8
                guard valueOffset + 2 <= data.count else { return false }
                if bigEndian {
                    data[valueOffset] = UInt8(newOrientation >> 8)
                    data[valueOffset + 1] = UInt8(newOrientation & 0xFF)
                } else {
                    data[valueOffset] = UInt8(newOrientation & 0xFF)
                    data[valueOffset + 1] = UInt8(newOrientation >> 8)
                }
                return true
            }
        }
        return false
    }
}
