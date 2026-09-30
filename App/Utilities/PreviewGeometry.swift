import CoreGraphics

/// Maps normalized image coordinates (top-left origin) to view coordinates for a
/// preview rendered with aspect-fill, so boxes line up with the live image even
/// when the preview crops the frame.
struct PreviewGeometry: Equatable {
    let viewSize: CGSize
    let imageSize: CGSize

    private var scale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    }

    private var displayed: CGSize {
        CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private var offset: CGPoint {
        CGPoint(x: (viewSize.width - displayed.width) / 2, y: (viewSize.height - displayed.height) / 2)
    }

    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + p.x * displayed.width, y: offset.y + p.y * displayed.height)
    }

    func rect(_ r: CGRect) -> CGRect {
        CGRect(x: offset.x + r.minX * displayed.width, y: offset.y + r.minY * displayed.height,
               width: r.width * displayed.width, height: r.height * displayed.height)
    }
}
