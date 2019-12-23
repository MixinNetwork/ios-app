import Foundation

extension NSNotification.Name {

    static let ConversationDidChange = NSNotification.Name("one.mixin.ios.sqlite.messages.changed")

    static let ContactsDidChange = NSNotification.Name("one.mixin.ios.contacts.changed")

    static let UserDidChange = NSNotification.Name("one.mixin.ios.user.changed")

    static let SyncMessageDidAppear = NSNotification.Name("one.mixin.ios.sync.message")

    static let ParticipantDidChange = NSNotification.Name("one.mixin.ios.participant.changed")

    static let AssetsDidChange = NSNotification.Name("one.mixin.ios.assets.changed")

    static let AssetVisibleDidChange = NSNotification.Name("one.mixin.ios.asset.visible.changed")

    static let SnapshotDidChange = NSNotification.Name("one.mixin.ios.snapshot.changed")

    static let AddressDidChange = NSNotification.Name("one.mixin.ios.addresses.changed")

    static let DefaultAddressDidChange = NSNotification.Name("one.mixin.ios.addresses.default.changed")

    static let FavoriteStickersDidChange = NSNotification.Name("one.mixin.ios.favorite.stickers.changed")
    
    static let StickerUsedAtDidUpdate = NSNotification.Name("one.mixin.ios.sticker.usedat.changed")
    
    static let StorageUsageDidChange = NSNotification.Name("one.mixin.ios.storage.changed")
    
    static let HiddenAssetsDidChange = NSNotification.Name("one.mixin.ios.hidden.assets.changed")

    static let BackupDidChange = NSNotification.Name("one.mixin.ios.backup.changed")

    static let UserSessionDidChange = NSNotification.Name("one.mixin.ios.session.changed")
}

struct ConversationChange {
    
    let conversationId: String
    let action: Action
    
    enum Action {
        case reload
        case update(conversation: ConversationItem)
        case updateConversation(conversation: ConversationResponse)
        case updateGroupIcon(iconUrl: String)
        case updateMessage(messageId: String)
        case updateMessageStatus(messageId: String, newStatus: MessageStatus)
        case updateMediaStatus(messageId: String, mediaStatus: MediaStatus)
        case updateUploadProgress(messageId: String, progress: Double)
        case updateDownloadProgress(messageId: String, progress: Double)
        case updateMediaContent(messageId: String, message: Message)
        case startedUpdateConversation
        case recallMessage(messageId: String)
    }
    
}
