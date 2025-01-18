import Foundation
import MixinServices

protocol AnyLocalized {
    var localizedDescription: String { get }
}

extension UnknownableEnum: AnyLocalized where T: AnyLocalized, T.RawValue == String {
    
    var localizedDescription: String {
        switch self {
        case .known(let value):
            value.localizedDescription
        case .unknown(let rawValue):
            rawValue
        }
    }
    
}
