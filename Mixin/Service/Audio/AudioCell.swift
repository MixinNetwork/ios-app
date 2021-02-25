import Foundation

enum AudioCellStyle {
    case playing
    case paused
    case stopped
}

protocol AudioCell: UITableViewCell {
    var style: AudioCellStyle { get set }
}
