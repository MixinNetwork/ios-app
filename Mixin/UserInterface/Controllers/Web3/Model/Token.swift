import Foundation
import MixinServices

protocol Token {
    var name: String { get }
    var symbol: String { get }
    var decimalBalance: Decimal { get }
    var decimalUSDPrice: Decimal { get }
}

extension MixinTokenItem: Token { }

extension Web3Token: Token { }

extension BalancedSwapToken: Token { }
