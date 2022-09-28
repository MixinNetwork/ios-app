import Foundation

struct TIPWatchRequest: Encodable {
    
    let watcher: String
    let action = "WATCH"
    
    init(watcher: Data) {
        self.watcher = watcher.hexEncodedString()
    }
    
}
