import UIKit

class BackupAvailabilityQuery {
    
    typealias Callback = ((Bool) -> Void)
    
    let query = NSMetadataQuery()
    
    var callback: Callback?
    
    deinit {
        query.stop()
    }
    
    func fileExist(callback: @escaping Callback) {
        guard let url = MixinFile.iCloudBackupDirectory else {
            callback(false)
            return
        }
        assert(self.callback == nil)
        self.callback = callback
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemPathKey, url.path)
        NotificationCenter.default.addObserver(self, selector: #selector(metadataQueryDidFinishGathering(_:)), name: .NSMetadataQueryDidFinishGathering, object: nil)
        query.start()
    }
    
    @objc func metadataQueryDidFinishGathering(_ notification: Notification) {
        query.disableUpdates()
        defer {
            query.enableUpdates()
        }
        callback?(!query.results.isEmpty)
        callback = nil
    }
    
}
