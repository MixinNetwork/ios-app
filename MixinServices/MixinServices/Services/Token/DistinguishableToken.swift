import Foundation

public protocol DistinguishableToken: Token {
    var isMalicious: Bool { get }
}
