import UIKit
import Rswift

class HomeAppsModelController: NSObject {
    
    class DragSessionContext {
        
        let fromIndexPath: IndexPath
        let dragFromPinned: Bool
        var didPerformDrop = false
        var dropToCandidate = false
        
        init(fromIndexPath: IndexPath, dragFromPinned: Bool) {
            self.fromIndexPath = fromIndexPath
            self.dragFromPinned = dragFromPinned
        }
        
    }
    
    private(set) lazy var moveAndInsertProposal = UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    private(set) lazy var feedback = UISelectionFeedbackGenerator()
    
    weak var collectionView: UICollectionView!
    
    var apps = [HomeApp]()
    
    var cellReuseIdentifier: String {
        fatalError("Must override")
    }
    
    init(collectionView: UICollectionView) {
        self.collectionView = collectionView
    }
    
    func dragPreviewParametersForItem(at indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? HomeAppCell else {
            return nil
        }
        let param = UIDragPreviewParameters()
        param.visiblePath = UIBezierPath(ovalIn: cell.imageViewFrame)
        return param
    }
    
}

extension HomeAppsModelController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! HomeAppCell
        let app = apps[indexPath.item]
        switch app {
        case .embedded(let app):
            cell.render(app: app)
        case .external(let user):
            cell.render(user: user)
        }
        return cell
    }
    
}

extension HomeAppsModelController: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = UIDragItem(itemProvider: NSItemProvider())
        let app = apps[indexPath.item]
        item.localObject = app
        feedback.selectionChanged()
        return [item]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        dragPreviewParametersForItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
        guard let app = session.items.first?.localObject as? HomeApp else {
            return
        }
        guard let item = apps.firstIndex(of: app) else {
            return
        }
        let indexPath = IndexPath(item: item, section: 0)
        session.localContext = DragSessionContext(fromIndexPath: indexPath,
                                                  dragFromPinned: self is PinnedHomeAppsModelController)
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        guard let context = session.localContext as? DragSessionContext, context.didPerformDrop else {
            return
        }
        let shouldRemoveTheApp = (self is PinnedHomeAppsModelController && context.dragFromPinned && context.dropToCandidate)
            || (self is CandidateHomeAppsModelController && !context.dragFromPinned && !context.dropToCandidate)
        if shouldRemoveTheApp {
            let indexPath = context.fromIndexPath
            apps.remove(at: indexPath.row)
            collectionView.deleteItems(at: [indexPath])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        true
    }
    
}
