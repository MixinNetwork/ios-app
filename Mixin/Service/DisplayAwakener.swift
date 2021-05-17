import Foundation
import MixinServices

class DisplayAwakener {
    
    typealias Token = UInt
    
    static let shared = DisplayAwakener()
    
    private var nextToken: Token = 0
    private var activeTokens: Set<Token> = []
    
    private init() {
        
    }
    
    func retain() -> Token {
        Queue.main.autoSync { () -> Token in
            let token = nextToken
            activeTokens.insert(token)
            UIApplication.shared.isIdleTimerDisabled = true
            nextToken += 1
            return token
        }
    }
    
    func release(token: Token) {
        Queue.main.autoSync {
            activeTokens.remove(token)
            if activeTokens.isEmpty {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
}
