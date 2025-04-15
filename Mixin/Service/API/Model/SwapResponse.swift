import Foundation

struct SwapResponse: Decodable {
    
    let tx: String?
    let depositDestination: String?
    let quote: QuoteResponse    
    
}
