import UIKit

class AuthorizationScopeDetailCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scopesView: AuthorizationScopesView!
    
    func render(group: AuthorizationScope.Group, scopes: [AuthorizationScope], dataSource: AuthorizationScopeDataSource) {
        imageView.image = group.icon
        titleLabel.text = group.title
        scopesView.render(scopes: scopes, dataSource: dataSource)
    }
    
}
