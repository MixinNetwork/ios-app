import UIKit
import MixinServices

class RefreshTopAssetsJob: AsynchronousJob {
    
    override func getJobId() -> String {
        return "refresh-top-assets"
    }
    
    override func execute() -> Bool {
        AssetAPI.shared.topAssets { (result) in
            switch result {
            case let .success(assets):
                TopAssetsDAO.shared.replaceAssets(assets)
            case .failure:
                break
            }
            self.finishJob()
        }
        return true
    }
    
}
