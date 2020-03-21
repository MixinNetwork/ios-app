import UIKit
import MapKit

class PinAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    private func prepare() {
        let pinImage = R.image.conversation.ic_annotation_pin()!
        image = pinImage
        bounds = CGRect(origin: .zero, size: pinImage.size)
        centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
    }
    
}
