import Foundation
import MixinServices

enum OneTimeAddressValidator {
    
    enum AddressError: Error, LocalizedError {
        
        case mismatchedDestination
        case mismatchedTag
        
        var errorDescription: String? {
            R.string.localizable.invalid_address()
        }
        
    }
    
    static func validate(
        assetID: String,
        destination: String,
        tag: String?,
        onSuccess: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let response = try await ExternalAPI.checkAddress(
                    assetID: assetID,
                    destination: destination,
                    tag: tag
                )
                guard destination.lowercased() == response.destination.lowercased() else {
                    throw AddressError.mismatchedDestination
                }
                guard (tag.isNilOrEmpty && response.tag.isNilOrEmpty) || tag == response.tag else {
                    throw AddressError.mismatchedTag
                }
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
}
