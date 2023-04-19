import Foundation
import MixinServices

class UserSearchResult: SearchResult {
    
    let user: UserItem
    
    private let keyword: String
    
    init(user: UserItem, keyword: String) {
        self.user = user
        self.keyword = keyword
        let badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified,
                                                     appId: user.appId)
        super.init(iconUrl: user.avatarUrl,
                   badgeImage: badgeImage,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: user.fullName,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        description = SearchResult.description(identityNumber: user.identityNumber,
                                               phoneNumber: user.phone,
                                               keyword: keyword)
    }
    
}
