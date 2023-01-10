import Foundation
import MixinServices

struct MixinTransferURL {
    
    let raw: String
    let queries: [String: String]
    
    init?(string raw: String) {
        guard ["bitcoin:", "bitcoincash:", "bitcoinsv:", "ethereum:", "litecoin:", "dash:", "ripple:", "zcash:", "horizen:", "monero:", "binancecoin:", "stellar:", "dogecoin:", "mobilecoin:"].contains(where: raw.lowercased().hasPrefix) else {
            return nil
        }
        guard let queries = URLComponents(string: raw)?.getKeyVals() else {
            return nil
        }
        guard let recipientId = queries["recipient"]?.lowercased(), let assetId = queries["asset"]?.lowercased() else {
            return nil
        }
        guard !recipientId.isEmpty && UUID(uuidString: recipientId) != nil && !assetId.isEmpty && UUID(uuidString: assetId) != nil else {
            return nil
        }
        self.queries = queries
        self.raw = raw
    }
    
}
