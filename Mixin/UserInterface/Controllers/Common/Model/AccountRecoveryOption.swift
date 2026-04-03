import Foundation
import MixinServices

enum AccountRecoveryOption: CaseIterable {
    
    case mobileNumber
    case mnemonicPhrase
    case recoveryContact
    
    static func enabledOptions(account: Account) -> [AccountRecoveryOption] {
        var options: [AccountRecoveryOption] = AccountRecoveryOption.allCases
        options.removeAll { option in
            switch option {
            case .mobileNumber:
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
