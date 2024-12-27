import Foundation
import MixinServices

protocol Web3TransferableToken {
    var name: String { get }
    var symbol: String { get }
    var decimalBalance: Decimal { get }
    var decimalUSDPrice: Decimal { get }
}

extension TokenItem: Web3TransferableToken { }

extension Web3Token: Web3TransferableToken { }

extension BalancedSwapToken: Web3TransferableToken { }
