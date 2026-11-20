import AppKit
import CoreGraphics

public enum Scrim {
    public static let spread: CGFloat = 2.4

    public static func falloff(_ t: CGFloat) -> CGFloat {
        pow(max(0, 1 - t), 2.2)
    }

    /// Generates a gradient image of opacity from top to bottom
    public static func generateImage(width: Int = 128, height: Int = 64, opacity: CGFloat = 0.25, darkText: Bool = false) -> CGImage? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        let baseColor: CGFloat = darkText ? 1.0 : 0.0 // black gradient for light text, white gradient for dark text
        for y in 0..<height {
            let t = CGFloat(y) / CGFloat(height)
            let alpha = opacity * falloff(t)
            let cByte = UInt8((baseColor * alpha * 255).rounded())
            let aByte = UInt8((alpha * 255).rounded())

            for x in 0..<width {
                let idx = (y * width + x) * 4
                data[idx] = cByte
                data[idx + 1] = cByte
                data[idx + 2] = cByte
                data[idx + 3] = aByte
            }
        }
        return ctx.makeImage()
    }
}
