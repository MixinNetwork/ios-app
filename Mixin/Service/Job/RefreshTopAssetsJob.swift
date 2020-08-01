import UIKit
import MixinServices

class RefreshTopAssetsJob: AsynchronousJob {
    
    override func getJobId() -> String {
        return "refresh-top-assets"
    }
    
    override func execute() -> Bool {
        AssetAPI.topAssets { (result) in
            switch result {
            case let .success(assets):
                DispatchQueue.global().async {
                    guard !MixinService.isStopProcessMessages else {
                        return
                    }
                    TopAssetsDAO.shared.replaceAssets(assets)
                }
            case .failure:
                break
            }
            self.finishJob()
        }
        return true
    }
    
}
