import Foundation
import MixinServices

final class AppUserSearchResult: SearchResult {
    
    let user: UserItem
    
    private let keyword: String
    
    init(user: User, keyword: String) {
        let item = UserItem.createUser(from: user)
        self.user = item
        self.keyword = keyword
        let badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified,
                                                     appId: user.appId)
        super.init(iconUrl: item.avatarUrl,
                   badgeImage: badgeImage,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: user.fullName,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        description = SearchResult.attributedText(text: user.identityNumber,
                                                  textAttributes: SearchResult.largerDescriptionAttributes,
                                                  keyword: keyword,
                                                  keywordAttributes: SearchResult.highlightedLargerDescriptionAttributes)
    }
    
}
