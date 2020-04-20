import UIKit
import MixinServices

protocol HomeAppCell: UICollectionViewCell {
    
    var imageViewFrame: CGRect { get }
    
    func render(user: User)
    func render(app: EmbeddedApp)
    
}
