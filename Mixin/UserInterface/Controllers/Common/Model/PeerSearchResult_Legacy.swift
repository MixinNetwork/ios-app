import Foundation

class PeerSearchResult_Legacy {
    
    let peer: Peer_Legacy
    let description: NSAttributedString?
    
    init(peer: Peer_Legacy, keyword: String) {
        self.peer = peer
        switch peer.item {
        case .group:
            self.description = nil
        case .user(let user):
            self.description = SearchResult.description(user: user, keyword: keyword)
        }
    }
    
}
