import Foundation
import UIKit

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
                if asset.isErrorAddress {
                    var userInfo = UIApplication.getTrackUserInfo()
                    userInfo["chainId"] = asset.chainId
                    userInfo["name"] = asset.name
                    userInfo["symbol"] = asset.symbol
                    userInfo["type"] = asset.type
                    userInfo["assetId"] = asset.assetId
                    userInfo["publicKey"] = asset.publicKey ?? ""
                    userInfo["accountName"] = asset.accountName ?? ""
                    userInfo["accountTag"] = asset.accountTag ?? ""
                    UIApplication.trackError("RefreshAssetsJob", action: "asset deposit data bad", userInfo: userInfo)
                }
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



