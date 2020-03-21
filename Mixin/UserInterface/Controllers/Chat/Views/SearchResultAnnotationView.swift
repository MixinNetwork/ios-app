import UIKit
import MapKit

class SearchResultAnnotationView: MKAnnotationView {
    
    private lazy var pinImage = R.image.conversation.ic_annotation_pin()!
    private lazy var pinImageView = UIImageView(image: pinImage)
    
    private var pinImageViewIfLoaded: UIView?
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            addSubview(pinImageView)
            pinImageView.center = CGPoint(x: bounds.midX, y: bounds.midY - pinImage.size.height / 2)
            pinImageViewIfLoaded = pinImageView
        } else {
            pinImageViewIfLoaded?.removeFromSuperview()
        }
    }
    
    private func prepare() {
        let annotationImage = R.image.conversation.ic_annotation_search_result()!
        image = annotationImage
        bounds = CGRect(origin: .zero, size: annotationImage.size)
        centerOffset = CGPoint(x: 0, y: 10)
    }
    
}
