import UIKit

class RefreshTopAssetsJob: BaseJob {
    
    override func getJobId() -> String {
        return "refresh-top-assets"
    }
    
    override func run() throws {
        switch AssetAPI.shared.topAssets() {
        case let .success(assets):
            TopAssetsDAO.shared.replaceAssets(assets)
        case let .failure(error):
            throw error
        }
    }
    
}
