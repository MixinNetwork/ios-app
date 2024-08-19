import Foundation
import MixinServices

class UserSearchResult: SearchResult {
    
    let user: UserItem
    
    private let keyword: String
    
    init(user: UserItem, keyword: String) {
        self.user = user
        self.keyword = keyword
        super.init(iconUrl: user.avatarUrl,
                   badgeImage: user.badgeImage,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: user.fullName,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        description = SearchResult.description(user: user, keyword: keyword)
    }
    
}
