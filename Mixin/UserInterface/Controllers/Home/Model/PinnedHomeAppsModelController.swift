import UIKit
import MixinServices

class PinnedHomeAppsModelController: HomeAppsModelController {
    
    override var cellReuseIdentifier: String {
        R.reuseIdentifier.home_app_selected.identifier
    }
    
    override func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        super.collectionView(collectionView, dragSessionDidEnd: session)
        AppGroupUserDefaults.User.homeAppIds = apps.map({ $0.id })
    }
    
    func reloadData(completion: @escaping ([HomeApp]) -> Void) {
        DispatchQueue.global().async {
            let ids = AppGroupUserDefaults.User.homeAppIds
            let apps = ids.compactMap(HomeApp.init)
            DispatchQueue.main.sync {
                self.apps = apps
                self.collectionView.reloadData()
                completion(apps)
            }
        }
    }
    
    private func destinationIndexPath(whenDroppingOn location: CGPoint, isDragFromPinnedApps: Bool) -> IndexPath? {
        var previousFrame: CGRect?
        for item in 0..<apps.count {
            let indexPath = IndexPath(item: item, section: 0)
            let frame = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
            if let previous = previousFrame, let current = frame {
                if location.x > previous.minX && location.x < current.maxX {
                    return IndexPath(item: item, section: 0)
                }
            }
            previousFrame = frame
        }
        if let previous = previousFrame, location.x > previous.maxX {
            if isDragFromPinnedApps {
                return IndexPath(item: apps.count - 1, section: 0)
            } else {
                return IndexPath(item: apps.count, section: 0)
            }
        }
        return nil
    }
    
}

extension PinnedHomeAppsModelController: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let item = coordinator.items.first, let app = item.dragItem.localObject as? HomeApp else {
            return
        }
        guard let context = coordinator.session.localDragSession?.localContext as? DragSessionContext else {
            return
        }
        let location = coordinator.session.location(in: collectionView)
        let destination = coordinator.destinationIndexPath
            ?? destinationIndexPath(whenDroppingOn: location, isDragFromPinnedApps: context.dragFromPinned)
            ?? IndexPath(item: 0, section: 0)
        if context.dragFromPinned {
            collectionView.performBatchUpdates({
                let app = apps.remove(at: context.fromIndexPath.item)
                apps.insert(app, at: destination.item)
                collectionView.moveItem(at: context.fromIndexPath, to: destination)
            }, completion: nil)
        } else {
            collectionView.performBatchUpdates({
                apps.insert(app, at: destination.item)
                collectionView.insertItems(at: [destination])
            }, completion: nil)
        }
        coordinator.drop(item.dragItem, toItemAt: destination)
        context.didPerformDrop = true
        context.dropToCandidate = false
        AppGroupUserDefaults.User.homeAppIds = apps.map({ $0.id })
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        guard let context = session.localDragSession?.localContext as? DragSessionContext else {
            return false
        }
        if context.dragFromPinned {
            return true
        } else {
            return apps.count < 4
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        moveAndInsertProposal
    }
    
    func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        dragPreviewParametersForItem(at: indexPath)
    }
    
}
