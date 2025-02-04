import Foundation
import MixinServices

protocol TransferableToken {
    var name: String { get }
    var symbol: String { get }
    var decimalBalance: Decimal { get }
    var decimalUSDPrice: Decimal { get }
}

extension TokenItem: TransferableToken { }

extension Web3Token: TransferableToken { }

extension BalancedSwapToken: TransferableToken { }
