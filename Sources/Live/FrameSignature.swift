import CoreGraphics

/// A tiny grayscale thumbnail used to skip text recognition when the region hasn't changed.
/// Cells are compared one by one: a new subtitle changes only part of the region,
/// which an average over the whole image would hide.
struct FrameSignature: Equatable {
    private static let columns = 96
    private static let rows = 24
    private let cells: [UInt8]

    init?(_ image: CGImage) {
        var buffer = [UInt8](repeating: 0, count: Self.columns * Self.rows)
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: Self.columns, height: Self.rows,
                                          bitsPerComponent: 8, bytesPerRow: Self.columns,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: Self.columns, height: Self.rows))
            return true
        }
        guard ok else { return nil }
        cells = buffer
    }

    func matches(_ other: FrameSignature, tolerance: Int = 8) -> Bool {
        zip(cells, other.cells).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }
}
