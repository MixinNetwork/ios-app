import UIKit
import MixinServices

protocol HomeItemModel: class {

    var id: String { get }
    var name: String { get }

}

protocol HomeAppCollectionCell: UICollectionViewCell {

    var snapshotView: UIView { get }
    var model: HomeItemModel? { get }
    
    func render(user: User)
    func render(app: EmbeddedApp)
    
    func enterEditingMode()
    func leaveEditingMode()
    
}
