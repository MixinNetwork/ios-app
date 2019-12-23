import Foundation

enum AudioCellStyle {
    case playing
    case paused
    case stopped
}

protocol AudioCell: class {
    var style: AudioCellStyle { get set }
}
