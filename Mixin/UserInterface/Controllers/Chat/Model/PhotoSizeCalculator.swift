import CoreGraphics

enum PhotoSizeCalculator {
    
    private enum Height {
        static let max: CGFloat = 280
        static let min: CGFloat = 120
    }
    
    private enum Width {
        static let max: CGFloat = 210
        static let min: CGFloat = 120
    }
    
    static func displaySize(for contentSize: CGSize) -> CGSize {
        let contentRatio = contentSize.height / contentSize.width
        let height: CGFloat
        let width: CGFloat
        if contentSize.width > Width.max && contentSize.height > Height.max {
            if contentRatio > 1 {
                if contentRatio > Height.max / Width.max {
                    height = Height.max
                    width = round(height / contentRatio)
                } else {
                    width = Width.max
                    height = round(width * contentRatio)
                }
            } else {
                width = Width.max
                height = max(Height.min, round(width * contentRatio))
            }
        } else if contentSize.height > Height.max && contentSize.width < Width.max {
            height = Height.max
            width = max(Width.min, round(height / contentRatio))
        } else if contentSize.width > Width.max && contentSize.height < Height.max {
            width = Width.max
            height = max(Height.min, round(width * contentRatio))
        } else if contentSize.width > Width.min && contentSize.height < Height.min {
            height = Height.min
            width = min(Width.max, round(height / contentRatio))
        } else if contentSize.height > Height.min && contentSize.width < Width.min {
            width = Width.min
            height = min(Height.max, round(width * contentRatio))
        } else if contentSize.height < Height.min && contentSize.width < Width.min {
            if contentRatio > 1 {
                width = Width.min
                height = min(Height.max, round(width * contentRatio))
            } else {
                height = Height.min
                width = min(Width.max, round(height / contentRatio))
            }
        } else {
            width = contentSize.width
            height = contentSize.height
        }
        return CGSize(width: width, height: height)
    }
    
}
