import Foundation
import MixinServices

enum AccountRecoveryOption: CaseIterable {
    
    case mobileNumber
    case mnemonicPhrase
    case recoveryContact
    
    static func enabledOptions(account: Account) -> [AccountRecoveryOption] {
        var options: [AccountRecoveryOption] = AccountRecoveryOption.allCases
        
        // Removes all options that user did not enabled
        options.removeAll { option in
            switch option {
            case .mobileNumber:
                // False value of `isAnonymous` indicates that user has never
                // registered his phone number
                account.isAnonymous
            case .mnemonicPhrase:
                !account.hasSaltExported
            case .recoveryContact:
                !account.hasEmergencyContact
            }
        }
        
        return options
    }
    
}
