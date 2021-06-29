import Foundation

extension HomeAppsManager {
    
    @discardableResult
    func showFolder(from cell: BotFolderCell, isNewFolder: Bool = false, startInRename: Bool = false) -> HomeAppsFolderViewController {
        let folderViewController = HomeAppsFolderViewController()
        return folderViewController
    }
    
    func startFolderOperation(for itemCell: BotItemCell) {
        
    }
    
    func cancelFolderOperation() {
        
    }
    
    func commitFolderOperation(didDrop: Bool = false) {
        
    }
    
}

extension HomeAppsManager {
    
    @objc func folderRemoveTimerHandler() {
        
    }
    
}
