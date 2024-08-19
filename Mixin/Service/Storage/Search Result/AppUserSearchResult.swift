import Foundation
import MixinServices

final class AppUserSearchResult: SearchResult {
    
    let user: User
    
    private let keyword: String
    
    init(user: User, keyword: String) {
        self.user = user
        self.keyword = keyword
        super.init(iconUrl: user.avatarUrl ?? "",
                   badgeImage: user.badgeImage,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: user.fullName ?? "",
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        description = SearchResult.attributedText(text: user.identityNumber,
                                                  textAttributes: SearchResult.largerDescriptionAttributes,
                                                  keyword: keyword,
                                                  keywordAttributes: SearchResult.highlightedLargerDescriptionAttributes)
    }
    
}
