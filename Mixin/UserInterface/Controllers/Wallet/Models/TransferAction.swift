import Foundation

enum TransferAction: Int, CaseIterable {
    
    case send
    case receive
    case swap
    
    var title: String {
        switch self {
        case .send:
            R.string.localizable.caption_send()
        case .receive:
            R.string.localizable.receive()
        case .swap:
            R.string.localizable.swap()
        }
    }
    
}
