import Foundation
import MixinServices

extension MessageItem {
    
    var quoteSubtitle: String {
        if category.hasSuffix("_TEXT") {
            return mentionedFullnameReplacedContent
        } else if category.hasSuffix("_STICKER") {
            return Localized.CHAT_QUOTE_TYPE_STICKER
        } else if category.hasSuffix("_IMAGE") {
            return Localized.CHAT_QUOTE_TYPE_PHOTO
        } else if category.hasSuffix("_VIDEO") {
            return Localized.CHAT_QUOTE_TYPE_VIDEO
        } else if category.hasSuffix("_LIVE") {
            return R.string.localizable.chat_quote_type_live()
        } else if category.hasSuffix("_POST") {
            return markdownControlCodeRemovedContent
        } else if category.hasSuffix("_AUDIO") {
            if let duration = mediaDuration {
                return mediaDurationFormatter.string(from: TimeInterval(Double(duration) / millisecondsPerSecond)) ?? ""
            } else {
                return ""
            }
        } else if category.hasSuffix("_DATA") {
            return name ?? ""
        } else if category.hasSuffix("_LOCATION") {
            return R.string.localizable.chat_quote_type_location()
        } else if category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            return (snapshotAmount ?? "0") + " " + (assetSymbol ?? "")
        } else if category.hasSuffix("_CONTACT") {
            return sharedUserIdentityNumber ?? ""
        } else if category == MessageCategory.APP_CARD.rawValue {
            return appCard?.description ?? ""
        } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
            return appButtons?.first?.label ?? ""
        } else if category == MessageCategory.SIGNAL_TRANSCRIPT.rawValue {
            return R.string.localizable.chat_transcript()
        } else {
            return ""
        }
    }
    
}
