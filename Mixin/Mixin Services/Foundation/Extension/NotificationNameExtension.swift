import Foundation

extension NSNotification.Name {

    static let ConversationDidChange = NSNotification.Name("one.mixin.services.sqlite.messages.changed")

    static let ContactsDidChange = NSNotification.Name("one.mixin.services.contacts.changed")

    static let UserDidChange = NSNotification.Name("one.mixin.services.user.changed")

    static let SyncMessageDidAppear = NSNotification.Name("one.mixin.services.sync.message")

    static let ParticipantDidChange = NSNotification.Name("one.mixin.services.participant.changed")

    static let AssetsDidChange = NSNotification.Name("one.mixin.services.assets.changed")

    static let AssetVisibleDidChange = NSNotification.Name("one.mixin.services.asset.visible.changed")

    static let SnapshotDidChange = NSNotification.Name("one.mixin.services.snapshot.changed")

    static let AddressDidChange = NSNotification.Name("one.mixin.services.addresses.changed")

    static let DefaultAddressDidChange = NSNotification.Name("one.mixin.services.addresses.default.changed")

    static let FavoriteStickersDidChange = NSNotification.Name("one.mixin.services.favorite.stickers.changed")
    
    static let StickerUsedAtDidUpdate = NSNotification.Name("one.mixin.services.sticker.usedat.changed")
    
    static let StorageUsageDidChange = NSNotification.Name("one.mixin.services.storage.changed")
    
    static let HiddenAssetsDidChange = NSNotification.Name("one.mixin.services.hidden.assets.changed")

    static let BackupDidChange = NSNotification.Name("one.mixin.services.backup.changed")

    static let UserSessionDidChange = NSNotification.Name("one.mixin.services.session.changed")
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
