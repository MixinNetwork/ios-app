import UIKit
import MixinServices

class CircleMemberSearchResult: SearchResult {
    
    let member: CircleMember
    
    private let keyword: String
    
    init(member: CircleMember, keyword: String) {
        self.member = member
        self.keyword = keyword
        super.init(iconUrl: member.iconUrl,
                   badgeImage: nil,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: member.name,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        description = SearchResult.description(identityNumber: member.identityNumber,
                                               phoneNumber: member.phoneNumber,
                                               keyword: keyword)
    }
    
}
