import UIKit

class AuthorizationScopeDetailCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scopeView: AuthorizationScopeTableView!
    
    func render(scopeGroup: Scope.GroupInfo, scopeHandler: AuthorizationScopeHandler) {
        imageView.image = scopeGroup.icon
        titleLabel.text = scopeGroup.title
        scopeView.render(scopeItems: scopeGroup.items, scopeHandler: scopeHandler)
    }
    
}
