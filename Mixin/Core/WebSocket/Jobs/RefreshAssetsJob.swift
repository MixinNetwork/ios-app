import Foundation

class RefreshAssetsJob: BaseJob {

    private let assetId: String?

    init(assetId: String? = nil) {
        self.assetId = assetId
    }

    override func getJobId() -> String {
        return "refresh-assets-\(assetId ?? "all")"
    }

    override func run() throws {
        if let assetId = self.assetId {
            switch AssetAPI.shared.asset(assetId: assetId) {
            case let .success(asset):
                AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
            case let .failure(error):
                throw error
            }
        } else {
            switch AssetAPI.shared.assets() {
            case let .success(assets):
                AssetDAO.shared.insertOrUpdateAssets(assets: assets)
            case let .failure(error):
                throw error
            }
        }
    }

}



