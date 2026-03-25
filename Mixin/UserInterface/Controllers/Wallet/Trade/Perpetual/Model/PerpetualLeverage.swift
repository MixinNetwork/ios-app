import Foundation

enum PerpetualLeverage {
    
    static func stringRepresentation(multiplier: Int) -> String {
        "\(multiplier)×"
    }
    
    static func stringRepresentation(multiplier: Decimal) -> String {
        "\(multiplier)×"
    }
    
}
