import Foundation

//TODO: fix this
extension CGAffineTransform {
    
    static func transform(rect fromRect: CGRect, to toRect: CGRect) -> CGAffineTransform {
        
        let scaleWidth = toRect.width / fromRect.width
        let scaleHeight = toRect.height / fromRect.height
        let transform = CGAffineTransform.identity.translatedBy(x: toRect.midX - fromRect.midX, y: toRect.midY - fromRect.midY)
        return transform.scaledBy(x: scaleWidth, y: scaleHeight)
    }
    
}
