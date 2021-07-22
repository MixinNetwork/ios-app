import Foundation

protocol HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction { get }
    var item: AppItem { get }
    var isDismissing: Bool { get set }
    var wrapperView: UIView { get }
    
}

class HomeAppsFolderCreationInteraction: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var item: AppItem
    var isDismissing: Bool = false
    var wrapperView: UIView
    let destinationApp: AppModel

    required init(dragInteraction: HomeAppsDragInteraction, destinationApp: AppModel, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.destinationApp = destinationApp
        self.item = destinationApp
        self.wrapperView = wrapperView
    }
    
}

class HomeAppsFolderDropInteraction: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var item: AppItem
    var isDismissing: Bool = false
    var wrapperView: UIView
    let folder: AppFolderModel

    required init(dragInteraction: HomeAppsDragInteraction, folder: AppFolderModel, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.folder = folder
        self.item = folder
        self.wrapperView = wrapperView
    }
    
}

class HomeAppsOpenFolderInfo {
    
    let folder: AppFolderModel
    let cell: AppFolderCell
    var isNewFolder: Bool
    var shouldCancelCreation = false
    
    required init(cell: AppFolderCell, isNewFolder: Bool) {
        self.cell = cell
        self.folder = cell.item as! AppFolderModel
        self.isNewFolder = isNewFolder
    }
    
}
