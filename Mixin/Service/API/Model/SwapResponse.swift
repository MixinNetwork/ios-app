import Foundation

struct SwapResponse: Decodable {
    
    let tx: String
    let quote: QuoteResponse
    
}
