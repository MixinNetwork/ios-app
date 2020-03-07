import UIKit
import MixinServices
import MapKit

class LocationMessageViewModel: ImageMessageViewModel {
    
    typealias Snapshot = (image: UIImage, annotationCenter: CGPoint)
    
    override class var bubbleWidth: CGFloat {
        296
    }
    
    let hasAddress: Bool
    
    override var statusNormalTintColor: UIColor {
        hasAddress ? .accessoryText : .white
    }
    
    override var trailingInfoColor: UIColor {
        hasAddress ? .accessoryText : .white
    }
    
    var cachedSnapshot: [UserInterfaceStyle: Snapshot] = [:]
    var informationFrame: CGRect?
    var labelsLeadingConstant: CGFloat = 20
    
    override init(message: MessageItem) {
        hasAddress = message.location?.address != nil
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        photoFrame.size = CGSize(width: Self.bubbleWidth, height: 180)
        super.layout(width: width, style: style)
        if style.contains(.received) {
            labelsLeadingConstant = 20
        } else {
            labelsLeadingConstant = 14
        }
        if hasAddress {
            photoFrame.size.height = 120
            informationFrame = CGRect(x: photoFrame.origin.x,
                                      y: photoFrame.maxY,
                                      width: photoFrame.width,
                                      height: 60)
        } else {
            photoFrame.size.height = 180
            informationFrame = nil
        }
        layoutTrailingInfoBackgroundFrame()
    }
    
}
