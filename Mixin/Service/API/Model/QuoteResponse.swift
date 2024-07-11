import Foundation

struct QuoteResponse: Decodable {
    
    let inputMint: String
    let inAmount: String
    let outputMint: String
    let outAmount: String
    let slippage: Int
    let source: String
    
}
