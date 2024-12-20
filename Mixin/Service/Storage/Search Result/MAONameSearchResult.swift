import UIKit
import MixinServices

final class MAONameSearchResult: SearchResult {
    
    let user: UserItem
    let app: App?
    
    private let name: String
    
    init(name: String, response: UserResponse) {
        let user = UserItem.createUser(from: response)
        self.name = name
        self.user = user
        self.app = response.app
        super.init(
            iconUrl: response.avatarUrl,
            badgeImage: user.badgeImage,
            superscript: nil
        )
    }
    
    override func updateTitleAndDescription() {
        title = NSAttributedString(string: user.fullName, attributes: SearchResult.titleAttributes)
        description = {
            let name = NSMutableAttributedString(string: name, attributes: SearchResult.highlightedNormalDescriptionAttributes)
            var suffixAttributes = SearchResult.highlightedNormalDescriptionAttributes
            suffixAttributes[.foregroundColor] = UIColor(displayP3RgbValue: 0xF7A500)
            name.append(NSAttributedString(string: ".mao", attributes: suffixAttributes))
            return name
        }()
    }
    
}
