import UIKit
import MapKit

class SearchResultAnnotationView: MKAnnotationView {
    
    private lazy var pinImageView = UIImageView(image: R.image.conversation.ic_annotation_pin())
    
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
            pinImageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            pinImageViewIfLoaded = pinImageView
        } else {
            pinImageViewIfLoaded?.removeFromSuperview()
        }
    }
    
    private func prepare() {
        let pinImage = R.image.conversation.ic_annotation_search_result()!
        image = pinImage
        bounds = CGRect(origin: .zero, size: pinImage.size)
    }
    
}
