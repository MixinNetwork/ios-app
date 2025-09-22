import Foundation
import MixinServices

enum DepositFilter {
    
    // Deposits returns from Safe API contains everything, whether it's mine or other's
    // Filter with my entries to get my deposits
    static func myDeposits(
        from deposits: [SafePendingDeposit],
        chainID: String? = nil
    ) -> [SafePendingDeposit] {
        let entries = DepositEntryDAO.shared.compactEntries(chainID: chainID)
        return deposits.filter { deposit in
            entries.contains(where: { (entry) in
                let isDestinationMatch = entry.destination == deposit.destination
                let isTagMatch: Bool
                if entry.tag.isNilOrEmpty && deposit.tag.isNilOrEmpty {
                    isTagMatch = true
                } else if entry.tag == deposit.tag {
                    isTagMatch = true
                } else {
                    isTagMatch = false
                }
                return isDestinationMatch && isTagMatch
            })
        }
    }
    
}
