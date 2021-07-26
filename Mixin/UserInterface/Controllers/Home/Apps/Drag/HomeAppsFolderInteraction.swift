import Foundation

protocol HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction { get }
    var item: HomeAppItem { get }
    var isDismissing: Bool { get set }
    var wrapperView: UIView { get }
    
}

class HomeAppsFolderCreationInteraction: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var item: HomeAppItem
    var isDismissing: Bool = false
    var wrapperView: UIView
    let destinationApp: HomeApp

    required init(dragInteraction: HomeAppsDragInteraction, destinationApp: HomeApp, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.destinationApp = destinationApp
        self.item = .app(destinationApp)
        self.wrapperView = wrapperView
    }
    
}

class HomeAppsFolderDropInteraction: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var item: HomeAppItem
    var isDismissing: Bool = false
    var wrapperView: UIView
    let folder: HomeAppFolder

    required init(dragInteraction: HomeAppsDragInteraction, folder: HomeAppFolder, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.folder = folder
        self.item = .folder(folder)
        self.wrapperView = wrapperView
    }
    
}

class HomeAppsOpenFolderInfo {
    
    let folder: HomeAppFolder
    let cell: AppFolderCell
    var isNewFolder: Bool
    var shouldCancelCreation = false
    
    required init(cell: AppFolderCell, isNewFolder: Bool) {
        self.cell = cell
        self.folder = cell.folder! // FIXME
        self.isNewFolder = isNewFolder
    }
    
}
