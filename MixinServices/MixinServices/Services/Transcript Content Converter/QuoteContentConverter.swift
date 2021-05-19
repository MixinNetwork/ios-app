import Foundation

enum QuoteContentConverter {
    
    // Due to historical reasons, we are using different serialization between database and transcript
    
    static func transcriptQuoteContent(from localQuoteContent: Data?) -> String? {
        guard let localQuoteContent = localQuoteContent else {
            return nil
        }
        guard let item = try? JSONDecoder.default.decode(MessageItem.self, from: localQuoteContent) else {
            return nil
        }
        let content = QuoteContent(item: item)
        guard let json = try? JSONEncoder.snakeCase.encode(content) else {
            return nil
        }
        return String(data: json, encoding: .utf8)
    }
    
    static func localQuoteContent(from transcriptQuoteContent: String?) -> Data? {
        guard let contentJson = transcriptQuoteContent?.data(using: .utf8)  else {
            return nil
        }
        guard let content = try? JSONDecoder.snakeCase.decode(QuoteContent.self, from: contentJson) else {
            return nil
        }
        let item = content.messageItem
        return try? JSONEncoder.default.encode(item)
    }
    
    private struct QuoteContent: Codable {
        
        let messageId: String
        let conversationId: String
        let userId: String
        let userFullName: String
        let userIdentityNumber: String
        let type: String
        let content: String?
        let createdAt: String
        let status: String
        let mediaStatus: String?
        let userAvatarUrl: String?
        let mediaName: String?
        let mediaMimeType: String?
        let mediaSize: Int64?
        let mediaWidth: Int?
        let mediaHeight: Int?
        let thumbImage: String?
        let thumbUrl: String?
        let mediaUrl: String?
        let mediaDuration: String?
        let assetUrl: String?
        let assetHeight: Int?
        let assetWidth: Int?
        let stickerId: String?
        let assetName: String?
        let appId: String?
        let sharedUserId: String?
        let sharedUserFullName: String?
        let sharedUserIdentityNumber: String?
        let sharedUserAvatarUrl: String?
        let mentions: String?
        
        var messageItem: MessageItem {
            let mediaDuration: Int64?
            if let md = self.mediaDuration {
                mediaDuration = Int64(md)
            } else {
                mediaDuration = nil
            }
            return MessageItem(messageId: messageId,
                               conversationId: conversationId,
                               userId: userId,
                               category: type,
                               content: content,
                               mediaUrl: mediaUrl,
                               mediaMimeType: mediaMimeType,
                               mediaSize: mediaSize,
                               mediaDuration: mediaDuration,
                               mediaWidth: mediaWidth,
                               mediaHeight: mediaHeight,
                               mediaHash: nil,
                               mediaKey: nil,
                               mediaDigest: nil,
                               mediaStatus: mediaStatus,
                               mediaWaveform: nil,
                               mediaLocalIdentifier: nil,
                               thumbImage: thumbImage,
                               thumbUrl: thumbUrl,
                               status: status,
                               participantId: nil,
                               snapshotId: nil,
                               name: mediaName,
                               stickerId: stickerId,
                               createdAt: createdAt,
                               actionName: nil,
                               userFullName: userFullName,
                               userIdentityNumber: userIdentityNumber,
                               userAvatarUrl: userAvatarUrl,
                               appId: appId,
                               snapshotAmount: nil,
                               snapshotAssetId: nil,
                               snapshotType: nil,
                               participantFullName: nil,
                               participantUserId: nil,
                               assetUrl: assetUrl,
                               assetType: nil,
                               assetSymbol: nil,
                               assetIcon: nil,
                               assetWidth: assetWidth,
                               assetHeight: assetHeight,
                               assetCategory: nil,
                               sharedUserId: sharedUserId,
                               sharedUserFullName: sharedUserFullName,
                               sharedUserIdentityNumber: sharedUserIdentityNumber,
                               sharedUserAvatarUrl: sharedUserAvatarUrl,
                               sharedUserAppId: nil,
                               sharedUserIsVerified: nil,
                               quoteMessageId: nil,
                               quoteContent: nil,
                               mentionsJson: nil,
                               hasMentionRead: nil)
        }
        
        init(item i: MessageItem) {
            self.messageId = i.messageId
            self.conversationId = i.conversationId
            self.userId = i.userId
            self.userFullName = i.userFullName ?? ""
            self.userIdentityNumber = i.userIdentityNumber ?? ""
            self.type = i.category
            self.content = i.content
            self.createdAt = i.createdAt
            self.status = i.status
            self.mediaStatus = i.mediaStatus
            self.userAvatarUrl = i.userAvatarUrl
            self.mediaName = i.name
            self.mediaMimeType = i.mediaMimeType
            self.mediaSize = i.mediaSize
            self.mediaWidth = i.mediaWidth
            self.mediaHeight = i.mediaHeight
            self.thumbImage = i.thumbImage
            self.thumbUrl = i.thumbUrl
            self.mediaUrl = i.mediaUrl
            self.mediaDuration = String(i.mediaDuration ?? 0)
            self.assetUrl = i.assetUrl
            self.assetHeight = i.assetHeight
            self.assetWidth = i.assetWidth
            self.stickerId = i.stickerId
            self.assetName = i.name
            self.appId = i.appId
            self.sharedUserId = i.sharedUserId
            self.sharedUserFullName = i.sharedUserFullName
            self.sharedUserIdentityNumber = i.sharedUserIdentityNumber
            self.sharedUserAvatarUrl = i.sharedUserAvatarUrl
            if let json = i.mentionsJson {
                self.mentions = String(data: json, encoding: .utf8)
            } else {
                self.mentions = nil
            }
        }
    }
    
}
