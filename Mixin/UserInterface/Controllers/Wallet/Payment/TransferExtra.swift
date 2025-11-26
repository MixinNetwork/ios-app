import Foundation

enum TransferExtra {
    
    case plain(String)
    case hexEncoded(String)
    
    var plainValue: String? {
        switch self {
        case .plain(let value):
            value
        case .hexEncoded(let hexEncoded):
            if let data = Data(hexEncodedString: hexEncoded),
               let value = String(data: data, encoding: .utf8)
            {
                value
            } else {
                nil
            }
        }
    }
    
    var hexEncodedValue: String? {
        switch self {
        case .plain(let plain):
            if let data = plain.data(using: .utf8) {
                data.hexEncodedString()
            } else {
                nil
            }
        case .hexEncoded(let value):
            value
        }
    }
    
}
