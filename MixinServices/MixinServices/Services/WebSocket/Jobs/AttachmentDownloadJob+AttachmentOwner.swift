import Foundation

extension AttachmentDownloadJob {
    
    public enum AttachmentOwner {
        
        case message(Message)
        case transcriptMessage(TranscriptMessage)
        
        var messageId: String {
            switch self {
            case .message(let message):
                return message.messageId
            case .transcriptMessage(let message):
                return message.messageId
            }
        }
        
        var category: String {
            switch self {
            case .message(let message):
                return message.category
            case .transcriptMessage(let message):
                return message.category.rawValue
            }
        }
        
        var content: String? {
            switch self {
            case .message(let message):
                return message.content
            case .transcriptMessage(let message):
                return message.content
            }
        }
        
        var mediaName: String? {
            switch self {
            case .message(let message):
                return message.name
            case .transcriptMessage(let message):
                return message.mediaName
            }
        }
        
        var mediaUrl: String? {
            switch self {
            case .message(let message):
                return message.mediaUrl
            case .transcriptMessage(let message):
                return message.mediaUrl
            }
        }
        
        var mediaMimeType: String? {
            switch self {
            case .message(let message):
                return message.mediaMimeType
            case .transcriptMessage(let message):
                return message.mediaMimeType
            }
        }
        
        var mediaKey: Data? {
            switch self {
            case .message(let message):
                return message.mediaKey
            case .transcriptMessage(let message):
                return message.mediaKey
            }
        }
        
        var mediaDigest: Data? {
            switch self {
            case .message(let message):
                return message.mediaDigest
            case .transcriptMessage(let message):
                return message.mediaDigest
            }
        }
        
        var mediaStatus: String? {
            switch self {
            case .message(let message):
                return message.mediaStatus
            case .transcriptMessage(let message):
                return message.mediaStatus
            }
        }
        
    }
    
}
