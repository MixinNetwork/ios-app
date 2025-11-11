import Foundation

public enum Wallet {
    case privacy
    case common(Web3Wallet)
}

extension Wallet: Equatable {
    
    public static func == (lhs: Wallet, rhs: Wallet) -> Bool {
        switch (lhs, rhs) {
        case (.privacy, .privacy):
            true
        case let (.common(l), .common(r)):
            l.walletID == r.walletID
        default:
            false
        }
    }
    
}

extension Wallet: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
        case .privacy:
            "PrivacyWallet"
        case .common(let wallet):
            "CommonWallet \(wallet.name)"
        }
    }
    
}

extension Wallet {
    
    public enum Identifier: RawRepresentable {
        
        case privacy
        case common(id: String)
        
        public init?(rawValue: String) {
            switch rawValue.first {
            case "p":
                self = .privacy
            case "c":
                let id = String(rawValue.dropFirst())
                self = .common(id: id)
            default:
                return nil
            }
        }
        
        public var rawValue: String {
            switch self {
            case .privacy:
                "p"
            case .common(let id):
                "c" + id
            }
        }
        
    }
    
    public var identifier: Identifier {
        switch self {
        case .privacy:
                .privacy
        case .common(let wallet):
                .common(id: wallet.walletID)
        }
    }
    
}
