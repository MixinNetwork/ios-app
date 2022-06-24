import UIKit
import MixinServices

class PhoneContactSearchResult: SearchResult {
    
    let contact: PhoneContact
    
    private let keyword: String
    
    init(contact: PhoneContact, keyword: String) {
        self.contact = contact
        self.keyword = keyword
        super.init(iconUrl: "", badgeImage: nil, superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: contact.fullName,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        if contact.phoneNumber.contains(keyword) {
            description = SearchResult.attributedText(text: contact.phoneNumber,
                                                      textAttributes: SearchResult.normalDescriptionAttributes,
                                                      keyword: keyword,
                                                      keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes)
        }
    }
    
}
