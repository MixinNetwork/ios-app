import Foundation
import MixinServices

struct AddressAssets: Decodable {
    let address: String
    let assets: [Web3Token]
}
