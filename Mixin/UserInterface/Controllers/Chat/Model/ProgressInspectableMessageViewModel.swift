import Foundation

protocol ProgressInspectableMessageCell {
    func updateProgress(viewModel: ProgressInspectableMessageViewModel)
}

protocol ProgressInspectableMessageViewModel {
    var mediaStatus: String? { get set }
    var progress: Double? { get set }
    var sizeRepresentation: String { get }
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

extension ProgressInspectableMessageViewModel where Self: MessageViewModel {

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
