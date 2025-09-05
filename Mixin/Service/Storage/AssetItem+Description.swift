import Foundation
import MixinServices

extension AssetItem {
    
    var memoLabel: String {
        return usesTag ? R.string.localizable.tag() : R.string.localizable.withdrawal_memo()
    }
    
}
