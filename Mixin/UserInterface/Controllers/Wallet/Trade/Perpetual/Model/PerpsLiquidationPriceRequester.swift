import Foundation
import MixinServices

class PerpsLiquidationPriceRequester {
    
    fileprivate let debounceInterval: UInt64 = 500 // In msec
    fileprivate let failRetryInterval: UInt64 = 3 // In sec
    
    fileprivate var task: Task<Void, Error>?
    
    func cancelLastRequest() {
        task?.cancel()
    }
    
}

final class OpenPerpsPositionLiquidationPriceRequester: PerpsLiquidationPriceRequester {
    
    private let marketID: String
    private let side: PerpetualOrderSide
    
    init(marketID: String, side: PerpetualOrderSide) {
        self.marketID = marketID
        self.side = side
    }
    
    @MainActor
    func request(
        amount: Decimal,
        leverage: Int,
        completion: @escaping @MainActor (Decimal) -> Void
    ) {
        task?.cancel()
        task = Task { [debounceInterval, marketID, side] in
            while LoginManager.shared.isLoggedIn {
                try await Task.sleep(nanoseconds: debounceInterval * NSEC_PER_MSEC)
                try Task.checkCancellation()
                do {
                    let price = try await RouteAPI.perpsLiquidationPrice(
                        request: .open(marketID: marketID, side: side, leverage: leverage),
                        amount: amount
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        completion(price)
                    }
                    return
                } catch {
                    Logger.general.error(category: "OpenPerpsPosition", message: "\(error)")
                    try await Task.sleep(nanoseconds: failRetryInterval * NSEC_PER_SEC)
                }
            }
        }
    }
    
}

final class AddPerpsPositionLiquidationPriceRequester: PerpsLiquidationPriceRequester {
    
    private let positionID: String
    
    init(positionID: String) {
        self.positionID = positionID
    }
    
    @MainActor
    func request(
        amount: Decimal,
        completion: @escaping @MainActor (Decimal) -> Void
    ) {
        task?.cancel()
        task = Task { [debounceInterval, positionID] in
            while LoginManager.shared.isLoggedIn {
                try await Task.sleep(nanoseconds: debounceInterval * NSEC_PER_MSEC)
                try Task.checkCancellation()
                do {
                    let price = try await RouteAPI.perpsLiquidationPrice(
                        request: .add(positionID: positionID),
                        amount: amount
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        completion(price)
                    }
                    return
                } catch {
                    Logger.general.error(category: "OpenPerpsPosition", message: "\(error)")
                    try await Task.sleep(nanoseconds: failRetryInterval * NSEC_PER_SEC)
                }
            }
        }
    }
    
}
