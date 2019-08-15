import Foundation
import SDWebImage

struct GroupIconMaker {
    
    enum Avatar {
        case image(UIImage)
        case generated(background: UIImage, name: String)
    }
    
    //    Multiple avatars is arranged by index like this
    //    +-----------+  +-----------+  +-----------+
    //    |         / |  | \   0   / |  | \   0   / |
    //    |  0    /   |  |   \   /   |  |   \   /   |
    //    |     /     |  |     |     |  | 1   X   2 |
    //    |   /   1   |  |  1  |  2  |  |   /   \   |
    //    | /         |  |     |     |  | /   3   \ |
    //    +-----------+  +-----------+  +-----------+
    static func make(participants: [ParticipantUser]) -> UIImage? {
        var avatars = [Avatar]()
        let semaphore = DispatchSemaphore(value: 0)
        for participant in participants {
            if !participant.userAvatarUrl.isEmpty, let url = URL(string: participant.userAvatarUrl) {
                SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil, completed: { (image, _, error, _, _, _) in
                    if let image = image {
                        avatars.append(.image(image))
                    }
                    semaphore.signal()
                })
                semaphore.wait()
            } else {
                let colorIndex = participant.userId.positiveHashCode() % 24 + 1
                if let background = UIImage(named: "AvatarBackground/color\(colorIndex)"), let firstLetter = participant.userFullName.first {
                    let name = String([firstLetter]).uppercased()
                    avatars.append(.generated(background: background, name: name))
                }
            }
            if avatars.count == 4 {
                break
            }
        }
        
        guard !avatars.isEmpty else {
            return nil
        }
        let fragments = avatars.enumerated().map { (index, avatar) -> UIImage in
            switch avatar {
            case let .image(image):
                return iconFragment(from: image, index: index, of: avatars.count)
            case let .generated(background, name):
                return iconFragment(name: name, background: background, index: index, of: avatars.count)
            }
        }
        
        guard fragments.count > 1 else {
            return fragments[0]
        }
        let canvasSize = CGSize(width: 512, height: 512)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image(actions: { (ctx) in
            for fragment in fragments {
                fragment.draw(in: canvasRect)
            }
            drawSeparatorLine(number: avatars.count)
        })
    }
    
    private static func iconFragment(from source: UIImage, index: Int, of numberOfPieces: Int) -> UIImage {
        guard numberOfPieces > 1 else {
            return source
        }
        let canvasSize = source.size
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let origin: CGPoint
        if numberOfPieces > 2, let faceRect = self.faceRect(in: source) {
            // fanMargin            fanMargin
            //  |←⎯⎯⎯⎯⎯→|               |←⎯⎯⎯⎯⎯→|
            //  ............................
            //    .  |   .   .   .   |   .
            //      .| .     .     . | .
            //        .  fan . fan   .
            //          .    .     .
            //            .  .  .
            //              ...
            if numberOfPieces == 3 {
                switch index {
                case 0:
                    let fanMargin = (1 - cos(.pi / 6)) * (faceRect.width / 2)
                    let minX = -fanMargin
                    let maxX = fanMargin
                    var x = -faceRect.origin.x + fanMargin + (canvasSize.width - 2 * fanMargin - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY = -canvasSize.height / 2
                    let maxY: CGFloat = 0
                    var y = -faceRect.origin.y - (canvasSize.width / 2 - faceRect.width / 2) / 2
                    y = max(minY, min(maxY, y))
                    origin = CGPoint(x: x, y: y)
                case 1:
                    let minX = -canvasSize.width / 2
                    let maxX: CGFloat = 0
                    var x = -faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY: CGFloat = 0
                    let maxY = canvasSize.height / 2 * sin(.pi / 6)
                    var y = -faceRect.origin.y + canvasSize.height / 3 * 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                default:
                    let minX: CGFloat = 0
                    let maxX = canvasSize.width / 2
                    var x = canvasSize.width - faceRect.maxX - (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY: CGFloat = 0
                    let maxY = canvasSize.height / 2 * sin(.pi / 6)
                    var y = -faceRect.origin.y + canvasSize.height / 3 * 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                }
            } else {
                let horizontalFanMargin = (sqrt(2) - 1) / sqrt(2) * (canvasSize.width / 2)
                let verticalFanMargin = (sqrt(2) - 1) / sqrt(2) * (canvasSize.height / 2)
                switch index {
                case 0:
                    let minX = -horizontalFanMargin
                    let maxX = horizontalFanMargin
                    var x = -faceRect.origin.x + horizontalFanMargin + (canvasSize.width - 2 * horizontalFanMargin - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY = -canvasSize.height / 2
                    let maxY: CGFloat = 0
                    var y = -faceRect.origin.y - (canvasSize.width / 2 - faceRect.width / 2) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                case 1:
                    let minX = -canvasSize.width / 2
                    let maxX: CGFloat = 0
                    var x = -faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 3
                    x = max(minX, min(maxX, x))
                    
                    let minY = -verticalFanMargin
                    let maxY = verticalFanMargin
                    var y = -faceRect.origin.y + canvasSize.height / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                case 2:
                    let minX: CGFloat = 0
                    let maxX = canvasSize.width / 2
                    var x = canvasSize.width - faceRect.maxX - (canvasSize.width / 2 - faceRect.width) / 3
                    x = max(minX, min(maxX, x))
                    
                    let minY = -verticalFanMargin
                    let maxY = verticalFanMargin
                    var y = -faceRect.origin.y + canvasSize.height / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                default:
                    let minX = -horizontalFanMargin
                    let maxX = horizontalFanMargin
                    var x = -faceRect.origin.x + horizontalFanMargin + (canvasSize.width - 2 * horizontalFanMargin - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY: CGFloat = 0
                    let maxY = canvasSize.height / 2
                    var y = faceRect.origin.y
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                }
            }
        } else {
            origin = .zero
        }
        return renderer.image { (ctx) in
            let path = self.path(size: canvasSize, index: index, of: numberOfPieces)
            path.addClip()
            source.draw(at: origin)
        }
    }
    
    private static func iconFragment(name: String, background: UIImage, index: Int, of numberOfPieces: Int) -> UIImage {
        let canvasSize = background.size
        
        let fontSize: CGFloat
        switch numberOfPieces {
        case 1:
            fontSize = 17
        case 2:
            fontSize = 15
        case 3:
            fontSize = 13
        default:
            fontSize = 12
        }
        
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes = [NSAttributedString.Key.font: font,
                          NSAttributedString.Key.foregroundColor: UIColor.white]
        let nameSize = name.size(withAttributes: attributes)
        
        let origin: CGPoint
        switch numberOfPieces {
        case 1:
            origin = CGPoint(x: (canvasSize.width - nameSize.width) / 2,
                             y: (canvasSize.height - nameSize.height) / 2)
        case 2:
            if index == 0 {
                origin = CGPoint(x: (canvasSize.width / 2 - nameSize.width / 2) / 2,
                                 y: (canvasSize.height / 2 - nameSize.height / 2) / 2)
            } else {
                origin = CGPoint(x: canvasSize.width / 2,
                                 y: canvasSize.height / 2)
            }
        case 3:
            switch index {
            case 0:
                origin = CGPoint(x: (canvasSize.width - nameSize.width) / 2,
                                 y: (canvasSize.height / 2 - nameSize.height) / 2)
            case 1:
                origin = CGPoint(x: (canvasSize.width / 2 - nameSize.width) / 2 + 2,
                                 y: canvasSize.height / 2)
            default:
                origin = CGPoint(x: (canvasSize.width / 2 - nameSize.width) / 2 - 2 + canvasSize.width / 2,
                                 y: canvasSize.height / 2)
            }
        default:
            switch index {
            case 0:
                origin = CGPoint(x: (canvasSize.width - nameSize.width) / 2,
                                 y: (canvasSize.height / 2 - nameSize.height) / 2 - 1)
            case 1:
                origin = CGPoint(x: (canvasSize.width / 2 - nameSize.width) / 2 - 1,
                                 y: (canvasSize.height - nameSize.height) / 2)
            case 2:
                origin = CGPoint(x: (canvasSize.width / 2 - nameSize.width) / 2 + canvasSize.width / 2 + 1,
                                 y: (canvasSize.height - nameSize.height) / 2)
            default:
                origin = CGPoint(x: (canvasSize.width - nameSize.width) / 2,
                                 y: (canvasSize.height / 2 - nameSize.height) / 2 + canvasSize.height / 2 + 1)
            }
        }
        
        let path = self.path(size: canvasSize, index: index, of: numberOfPieces)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { (ctx) in
            path.addClip()
            background.draw(in: CGRect(origin: .zero, size: canvasSize))
            (name as NSString).draw(at: origin, withAttributes: attributes)
        }
    }
    
    private static func path(size: CGSize, index: Int, of numberOfPieces: Int) -> UIBezierPath {
        let path = UIBezierPath()
        let topLeft = CGPoint.zero
        let topRight = CGPoint(x: size.width, y: 0)
        let bottomLeft = CGPoint(x: 0, y: size.height)
        let bottomRight = CGPoint(x: size.width, y: size.height)
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        switch numberOfPieces {
        case 2:
            if index == 0 {
                path.move(to: topLeft)
                path.addLine(to: topRight)
                path.addLine(to: bottomLeft)
                path.addLine(to: topLeft)
            } else {
                path.move(to: topRight)
                path.addLine(to: bottomRight)
                path.addLine(to: bottomLeft)
                path.addLine(to: topRight)
            }
        case 3:
            let p = (1 - tan(.pi / 6)) * size.height / 2
            let leftP = CGPoint(x: 0, y: p)
            let rightP = CGPoint(x: size.width, y: p)
            let bottomCenter = CGPoint(x: size.width / 2, y: size.height)
            switch index {
            case 0:
                path.move(to: .zero)
                path.addLine(to: topRight)
                path.addLine(to: rightP)
                path.addLine(to: middle)
                path.addLine(to: leftP)
                path.addLine(to: .zero)
            case 1:
                path.move(to: middle)
                path.addLine(to: bottomCenter)
                path.addLine(to: bottomLeft)
                path.addLine(to: leftP)
                path.addLine(to: middle)
            default:
                path.move(to: middle)
                path.addLine(to: rightP)
                path.addLine(to: bottomRight)
                path.addLine(to: bottomCenter)
                path.addLine(to: middle)
            }
        default:
            switch index {
            case 0:
                path.move(to: topLeft)
                path.addLine(to: topRight)
                path.addLine(to: middle)
                path.addLine(to: topLeft)
            case 1:
                path.move(to: topLeft)
                path.addLine(to: middle)
                path.addLine(to: bottomLeft)
                path.addLine(to: topLeft)
            case 2:
                path.move(to: topRight)
                path.addLine(to: bottomRight)
                path.addLine(to: middle)
                path.addLine(to: topRight)
            default:
                path.move(to: middle)
                path.addLine(to: bottomRight)
                path.addLine(to: bottomLeft)
                path.addLine(to: middle)
            }
        }
        path.close()
        return path
    }
    
    private static func faceRect(in image: UIImage) -> CGRect? {
        guard let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: nil) else {
            return nil
        }
        guard let image = CIImage(image: image) else {
            return nil
        }
        var options = [String: Any]()
        if let orientation = image.properties[kCGImagePropertyOrientation as String] {
            options[CIDetectorImageOrientation] = orientation
        }
        let features = detector.features(in: image, options: options)
        let faces = features.compactMap({ $0 as? CIFaceFeature })
        guard faces.count == 1 else {
            return nil
        }
        return faces[0].bounds
    }
    
    private static func drawSeparatorLine(number: Int) {
        guard [2, 3, 4].contains(number) else {
            return
        }
        guard let url = Bundle.main.url(forResource: "separator_\(number)", withExtension: "png") else {
            return
        }
        guard let image = UIImage(contentsOfFile: url.path) else {
            return
        }
        image.draw(at: .zero)
    }
    
}
