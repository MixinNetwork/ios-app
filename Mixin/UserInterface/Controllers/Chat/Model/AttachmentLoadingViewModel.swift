import Foundation

protocol AttachmentLoadingViewModel: class {
    var isLoading: Bool { get set }
    var progress: Double? { get set }
    var showPlayIconOnMediaStatusDone: Bool { get }
    var operationButtonStyle: NetworkOperationButton.Style { get set }
    var shouldUpload: Bool { get } // false if should download
    var automaticallyLoadsAttachment: Bool { get }
    var mediaStatus: String? { get set }
    var sizeRepresentation: String { get }
    var shouldAutoDownload: Bool { get }
    func beginAttachmentLoading(isTriggeredByUser: Bool)
    func cancelAttachmentLoading(isTriggeredByUser: Bool)
    func shouldBeginAttachmentLoading(isTriggeredByUser: Bool) -> Bool
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
    
    var shouldUpload: Bool {
        let hasMediaUrl = message.mediaUrl != nil
        let hasLocalIdentifier = message.mediaLocalIdentifier != nil
        return (message.userId == myUserId)
            && (hasMediaUrl || hasLocalIdentifier)
    }
    
    var mediaStatus: String? {
        get {
            return message.mediaStatus
        }
        set {
            message.mediaStatus = newValue
            if newValue != MediaStatus.PENDING.rawValue {
                progress = nil
                isLoading = false
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
    
    func updateOperationButtonStyle() {
        if let mediaStatus = mediaStatus {
            switch mediaStatus {
            case MediaStatus.PENDING.rawValue:
                if isLoading || shouldUpload {
                    operationButtonStyle = .busy(progress: 0)
                } else {
                    fallthrough
                }
            case MediaStatus.CANCELED.rawValue:
                if shouldUpload {
                    operationButtonStyle = .upload
                } else {
                    operationButtonStyle = .download
                }
            case MediaStatus.DONE.rawValue, MediaStatus.READ.rawValue:
                operationButtonStyle = .finished(showPlayIcon: showPlayIconOnMediaStatusDone)
            case MediaStatus.EXPIRED.rawValue:
                operationButtonStyle = .expired
            default:
                break
            }
        } else {
            operationButtonStyle = .finished(showPlayIcon: showPlayIconOnMediaStatusDone)
        }
    }
    
    func shouldBeginAttachmentLoading(isTriggeredByUser: Bool) -> Bool {
        let mediaStatusIsPendingOrCancelled = message.mediaStatus == MediaStatus.PENDING.rawValue || message.mediaStatus == MediaStatus.CANCELED.rawValue
        return (message.mediaStatus == MediaStatus.PENDING.rawValue && shouldAutoDownload)
            || (mediaStatusIsPendingOrCancelled && isTriggeredByUser)
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
