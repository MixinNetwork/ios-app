import Foundation

class UserSearchResult: SearchResult {
    
    let user: UserItem
    
    init(user: UserItem, keyword: String) {
        self.user = user
        let title = SearchResult.attributedText(text: user.fullName,
                                                 textAttributes: SearchResult.titleAttributes,
                                                 keyword: keyword,
                                                 keywordAttributes: SearchResult.highlightedTitleAttributes)
        let badgeImage = SearchResult.userBadgeImage(isVerified: user.isVerified,
                                                      appId: user.appId)
        let description = SearchResult.description(user: user, keyword: keyword)
        super.init(iconUrl: user.avatarUrl,
                   title: title,
                   badgeImage: badgeImage,
                   superscript: nil,
                   description: description)
    }
    
}
