import Foundation

protocol AttachmentLoadingViewModel: class {
    var progress: Double? { get set }
    var showPlayIconAfterFinished: Bool { get }
    var operationButtonStyle: NetworkOperationButton.Style { get set }
    var messageIsSentByMe: Bool { get }
    var automaticallyLoadsAttachment: Bool { get }
    var mediaStatus: String? { get set }
    var sizeRepresentation: String { get }
    func beginAttachmentLoading()
    func cancelAttachmentLoading(markMediaStatusCancelled: Bool)
}

enum ProgressUnit {
    case byte
    case kb
    case mb
    
    init(sizeInBytes: Int64) {
        if sizeInBytes < 1024 {
            self = .byte
        } else {
            let sizeInKB = sizeInBytes / 1024
            if sizeInKB <= 1024 {
                self = .kb
            } else {
                self = .mb
            }
        }
    }
}

extension AttachmentLoadingViewModel where Self: MessageViewModel {
    
    var messageIsSentByMe: Bool {
        return message.userId == AccountAPI.shared.accountUserId
    }
    
    var mediaStatus: String? {
        get {
            return message.mediaStatus
        }
        set {
            message.mediaStatus = newValue
            if newValue != MediaStatus.PENDING.rawValue {
                progress = nil
            }
            updateOperationButtonStyle()
        }
    }
    
    var sizeRepresentation: String {
        let size = message.mediaSize ?? 0
        let unit = ProgressUnit(sizeInBytes: size)
        if let progress = progress {
            let finishedBytes = Int64(progress * Double(size))
            return "\(sizeRepresentation(ofSizeInBytes: finishedBytes, unit: unit)) / \(sizeRepresentation(ofSizeInBytes: size, unit: unit))"
        } else {
            return sizeRepresentation(ofSizeInBytes: size, unit: unit)
        }
    }
    
    internal func updateOperationButtonStyle() {
        let sentByMe = message.userId == AccountAPI.shared.accountUserId
        if let mediaStatus = mediaStatus {
            switch mediaStatus {
            case MediaStatus.PENDING.rawValue:
                operationButtonStyle = .busy(progress: 0)
            case MediaStatus.CANCELED.rawValue:
                if sentByMe {
                    operationButtonStyle = .upload
                } else {
                    operationButtonStyle = .download
                }
            case MediaStatus.DONE.rawValue:
                operationButtonStyle = .finished(showPlayIcon: showPlayIconAfterFinished)
            case MediaStatus.EXPIRED.rawValue:
                operationButtonStyle = .expired
            default:
                break
            }
        } else {
            operationButtonStyle = .finished(showPlayIcon: showPlayIconAfterFinished)
        }
    }
    
    private func sizeRepresentation(ofSizeInBytes size: Int64, unit: ProgressUnit) -> String {
        switch unit {
        case .byte:
            return "\(size) Bytes"
        case .kb:
            return "\(size / 1024) KB"
        case .mb:
            return "\(size / 1024 / 1024) MB"
        }
    }
    
}
