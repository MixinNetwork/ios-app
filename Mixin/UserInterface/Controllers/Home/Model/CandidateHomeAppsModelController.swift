import UIKit
import MixinServices

class CandidateHomeAppsModelController: HomeAppsModelController {
    
    private(set) lazy var dropInteraction = UIDropInteraction(delegate: self)
    
    override var cellReuseIdentifier: String {
        R.reuseIdentifier.home_app.identifier
    }
    
    func reloadData(completion: @escaping ([User]) -> Void) {
        DispatchQueue.global().async { [weak self] in
            let pinned = Set(AppGroupUserDefaults.User.homeAppIds)
            
            var embeddedApps = EmbeddedApp.all
            embeddedApps.removeAll(where: {
                pinned.contains($0.id)
            })
            
            var appUsers = UserDAO.shared.getAppUsers()
            appUsers.removeAll(where: {
                if let id = $0.appId {
                    return pinned.contains(id)
                } else {
                    return true
                }
            })
            
            let apps: [HomeApp] = embeddedApps.map({ .embedded($0) }) + appUsers.map({ .external($0) })
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.apps = apps
                self.collectionView.reloadData()
                completion(appUsers)
            }
        }
    }
    
}

extension CandidateHomeAppsModelController: UIDropInteractionDelegate {
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        moveAndInsertProposal
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        guard let app = session.items.first?.localObject as? HomeApp else {
            return
        }
        guard let context = session.localDragSession?.localContext as? DragSessionContext else {
            return
        }
        guard context.dragFromPinned else {
            return
        }
        let item: Int
        let embeddedIds = apps.map(\.id)
        switch app {
        case .embedded(let app):
            if let index = embeddedIds.firstIndex(where: { $0 > app.id }) {
                item = index
            } else {
                item = embeddedIds.count
            }
        case .external(let user):
            let usernames = apps.compactMap({ (app) -> String? in
                switch app {
                case .embedded:
                    return nil
                case .external(let user):
                    return user.fullName
                }
            })
            if let index = usernames.firstIndex(where: { $0 > (user.fullName ?? "") }) {
                item = embeddedIds.count + index
            } else {
                item = apps.count
            }
        }
        let destination = IndexPath(item: item, section: 0)
        collectionView.performBatchUpdates({
            apps.insert(app, at: destination.item)
            collectionView.insertItems(at: [destination])
        }, completion: nil)
        context.didPerformDrop = true
        context.dropToCandidate = true
    }
    
}
