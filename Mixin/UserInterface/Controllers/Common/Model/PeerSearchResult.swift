import Foundation

class PeerSearchResult {
    
    let peer: Peer
    let description: NSAttributedString?
    
    init(peer: Peer, keyword: String) {
        self.peer = peer
        switch peer.item {
        case .group:
            self.description = nil
        case .user(let user):
            self.description = SearchResult.description(user: user, keyword: keyword)
        }
    }
    
}
