import UIKit
import MapKit

class AnnotationView: MKAnnotationView {
    
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
    }
    
}
