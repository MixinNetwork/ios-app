import Foundation
import MixinServices

extension TIPNodeResponseError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case TIPNodeResponseError.tooManyRequests:
            R.string.localizable.error_too_many_request()
        case .incorrectPIN:
            R.string.localizable.error_two_parts("\(code)", R.string.localizable.pin_incorrect())
        case .internalServer:
            R.string.localizable.error_two_parts("\(code)", R.string.localizable.mixin_server_encounters_errors())
        default:
            R.string.localizable.error_two_parts("\(code)", "Node Error")
        }
    }
    
}
