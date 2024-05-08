import Foundation
import MixinServices

protocol Web3TransferableToken {
    var name: String { get }
    var symbol: String { get }
    var decimalBalance: Decimal { get }
    var decimalUSDPrice: Decimal { get }
    var iconURL: String { get }
}

extension TokenItem: Web3TransferableToken { }

extension Web3Token: Web3TransferableToken { }
