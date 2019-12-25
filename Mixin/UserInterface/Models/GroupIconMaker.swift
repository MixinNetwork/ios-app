import Foundation
import SDWebImage
import FirebaseMLVision
import MixinServices

enum GroupIconMaker {
    
    private static let faceDetector: VisionFaceDetector = {
        let options = VisionFaceDetectorOptions()
        let vision = Vision.vision()
        return vision.faceDetector()
    }()
    
    private enum AvatarRepresentation {
        case image(UIImage)
        case composed(background: UIImage, name: String)
    }
    
    static func make(participants: [ParticipantUser]) -> UIImage? {
        var avatars = [AvatarRepresentation]()
        let semaphore = DispatchSemaphore(value: 0)
        for participant in participants {
            var isSucceed = false
            if !participant.userAvatarUrl.isEmpty, let url = URL(string: participant.userAvatarUrl) {
                SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil, completed: { (image, _, error, _, _, _) in
                    if error == nil, let image = image {
                        avatars.append(.image(image))
                        isSucceed = true
                    } else {
                        Reporter.report(error: MixinError.loadAvatar(url: url, error: error))
                    }
                    semaphore.signal()
                })
                semaphore.wait()
            } else {
                let colorIndex = participant.userId.positiveHashCode() % 24 + 1
                if let background = UIImage(named: "AvatarBackground/color\(colorIndex)"), let firstLetter = participant.userFullName.first {
                    let name = String([firstLetter]).uppercased()
                    avatars.append(.composed(background: background, name: name))
                    isSucceed = true
                }
            }
            if !isSucceed {
                return nil
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
            case let .composed(background, name):
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
            drawSeparatorLine(number: avatars.count, in: canvasRect)
        })
    }
    
    private static func iconFragment(from source: UIImage, index: Int, of numberOfPieces: Int) -> UIImage {
        guard numberOfPieces > 1 else {
            return source
        }
        let canvasSize = source.size
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let rect: CGRect
        if let faceRect = self.faceRect(in: source) {
            let origin: CGPoint
            switch numberOfPieces {
            case 2:
                switch index {
                case 0:
                    let minX = -canvasSize.width / 2
                    let maxX: CGFloat = 0
                    var x = -faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    origin = CGPoint(x: x, y: 0)
                default:
                    let minX: CGFloat = 0
                    let maxX = canvasSize.width / 2
                    var x = canvasSize.width / 2 - faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    origin = CGPoint(x: x, y: 0)
                }
            case 3:
                switch index {
                case 0:
                    let minX = -canvasSize.width / 2
                    let maxX: CGFloat = 0
                    var x = -faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    origin = CGPoint(x: x, y: 0)
                case 1:
                    let minX = -canvasSize.width / 2
                    let maxX = canvasSize.width / 2
                    var x = canvasSize.width / 2 - faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY = -canvasSize.height / 2
                    let maxY: CGFloat = 0
                    var y = -faceRect.origin.y + (canvasSize.height / 2 - faceRect.height) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                default:
                    let minX = -canvasSize.width / 2
                    let maxX = canvasSize.width / 2
                    var x = canvasSize.width / 2 - faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY: CGFloat = 0
                    let maxY = canvasSize.height / 2
                    var y = canvasSize.height / 2 - faceRect.origin.y + (canvasSize.height / 2 - faceRect.height) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                }
            default:
                switch index {
                case 0:
                    let minX = -canvasSize.width / 2
                    let maxX: CGFloat = 0
                    var x = -faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY = -canvasSize.height / 2
                    let maxY: CGFloat = 0
                    var y = -faceRect.origin.y + (canvasSize.height / 2 - faceRect.height) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                case 1:
                    let minX: CGFloat = 0
                    let maxX = canvasSize.height / 2
                    var x = canvasSize.width / 2 - faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY = -canvasSize.height / 2
                    let maxY: CGFloat = 0
                    var y = -faceRect.origin.y + (canvasSize.height / 2 - faceRect.height) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                case 2:
                    let minX = -canvasSize.width / 2
                    let maxX: CGFloat = 0
                    var x = -faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY: CGFloat = 0
                    let maxY = canvasSize.height / 2
                    var y = canvasSize.height / 2 - faceRect.origin.y + (canvasSize.height / 2 - faceRect.height) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                default:
                    let minX: CGFloat = 0
                    let maxX = canvasSize.height / 2
                    var x = canvasSize.width / 2 - faceRect.origin.x + (canvasSize.width / 2 - faceRect.width) / 2
                    x = max(minX, min(maxX, x))
                    
                    let minY: CGFloat = 0
                    let maxY = canvasSize.height / 2
                    var y = canvasSize.height / 2 - faceRect.origin.y + (canvasSize.height / 2 - faceRect.height) / 2
                    y = max(minY, min(maxY, y))
                    
                    origin = CGPoint(x: x, y: y)
                }
            }
            rect = CGRect(origin: origin, size: canvasSize)
        } else {
            switch numberOfPieces {
            case 2:
                switch index {
                case 0:
                    rect = CGRect(x: -canvasSize.width / 4, y: 0, width: canvasSize.width, height: canvasSize.height)
                default:
                    rect = CGRect(x: canvasSize.width / 4, y: 0, width: canvasSize.width, height: canvasSize.height)
                }
            case 3:
                switch index {
                case 0:
                    rect = CGRect(x: -canvasSize.width / 4, y: 0, width: canvasSize.width, height: canvasSize.height)
                case 1:
                    rect = CGRect(x: canvasSize.width / 2, y: 0, width: canvasSize.width / 2, height: canvasSize.height / 2)
                default:
                    rect = CGRect(x: canvasSize.width / 2, y: canvasSize.height / 2, width: canvasSize.width / 2, height: canvasSize.height / 2)
                }
            default:
                let size = CGSize(width: canvasSize.width / 2, height: canvasSize.height / 2)
                let origin: CGPoint
                switch index {
                case 0:
                    origin = CGPoint(x: 0, y: 0)
                case 1:
                    origin = CGPoint(x: canvasSize.width / 2, y: 0)
                case 2:
                    origin = CGPoint(x: 0, y: canvasSize.height / 2)
                default:
                    origin = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                }
                rect = CGRect(origin: origin, size: size)
            }
        }
        return renderer.image { (ctx) in
            let path = self.path(size: canvasSize, index: index, of: numberOfPieces)
            path.addClip()
            source.draw(in: rect)
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
        let offset: CGFloat = 2
        switch numberOfPieces {
        case 1:
            origin = CGPoint(x: (canvasSize.width - nameSize.width) / 2,
                             y: (canvasSize.height - nameSize.height) / 2)
        case 2:
            let nameMargin = (canvasSize.width / 2 - nameSize.width) / 2
            let y = (canvasSize.height - nameSize.height) / 2
            if index == 0 {
                origin = CGPoint(x: nameMargin + offset, y: y)
            } else {
                origin = CGPoint(x: canvasSize.width / 2 + nameMargin - offset, y: y)
            }
        case 3:
            let nameMargin = (canvasSize.width / 2 - nameSize.width) / 2
            switch index {
            case 0:
                origin = CGPoint(x: nameMargin + offset,
                                 y: (canvasSize.height - nameSize.height) / 2)
            case 1:
                origin = CGPoint(x: canvasSize.width / 2 + nameMargin - offset,
                                 y: (canvasSize.height / 2 - nameSize.height) / 2 + offset)
            default:
                origin = CGPoint(x: canvasSize.width / 2 + nameMargin - offset,
                                 y: canvasSize.height / 2 + (canvasSize.height / 2 - nameSize.height) / 2 - offset)
            }
        default:
            let horizontalNameMargin = (canvasSize.width / 2 - nameSize.width) / 2
            let verticalNameMargin = (canvasSize.height / 2 - nameSize.height) / 2
            switch index {
            case 0:
                origin = CGPoint(x: horizontalNameMargin + offset,
                                 y: verticalNameMargin + offset)
            case 1:
                origin = CGPoint(x: canvasSize.width / 2 + horizontalNameMargin - offset,
                                 y: verticalNameMargin + offset)
            case 2:
                origin = CGPoint(x: horizontalNameMargin + offset,
                                 y: canvasSize.height / 2 + verticalNameMargin - offset)
            default:
                origin = CGPoint(x: canvasSize.width / 2 + horizontalNameMargin - offset,
                                 y: canvasSize.height / 2 + verticalNameMargin - offset)
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
        let rect: CGRect
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        switch numberOfPieces {
        case 1:
            rect = CGRect(origin: .zero, size: size)
        case 2:
            if index == 0 {
                rect = CGRect(x: 0, y: 0, width: halfWidth, height: size.height)
            } else {
                rect = CGRect(x: halfWidth, y: 0, width: halfWidth, height: size.height)
            }
        case 3:
            switch index {
            case 0:
                rect = CGRect(x: 0, y: 0, width: halfWidth, height: size.height)
            case 1:
                rect = CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)
            default:
                rect = CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
            }
        default:
            switch index {
            case 0:
                rect = CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight)
            case 1:
                rect = CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)
            case 2:
                rect = CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight)
            default:
                rect = CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
            }
        }
        return UIBezierPath(rect: rect)
    }
    
    private static func faceRect(in image: UIImage) -> CGRect? {
        let visionImage = VisionImage(image: image)
        let sema = DispatchSemaphore(value: 0)
        var face: VisionFace?
        faceDetector.process(visionImage) { (faces, error) in
            if let faces = faces, faces.count == 1 {
                face = faces[0]
            }
            sema.signal()
        }
        sema.wait()
        return face?.frame
    }
    
    private static func drawSeparatorLine(number: Int, in rect: CGRect) {
        guard [2, 3, 4].contains(number) else {
            return
        }
        guard let url = Bundle.main.url(forResource: "group_separator_\(number)", withExtension: "png") else {
            return
        }
        guard let image = UIImage(contentsOfFile: url.path) else {
            return
        }
        image.draw(in: rect)
    }
    
}
