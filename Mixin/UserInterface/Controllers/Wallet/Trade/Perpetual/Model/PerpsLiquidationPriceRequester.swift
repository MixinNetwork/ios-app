import Foundation
import MixinServices

class PerpsLiquidationPriceRequester {
    
    enum LiquidationPriceError {
        
        enum Intent {
            case open
            case edit
        }
        
        case exceedsMaxRemovableMargin(Decimal)
        case other(description: String)
        
        var localizedDescription: String {
            switch self {
            case .exceedsMaxRemovableMargin(let value):
                R.string.localizable.max_removable(
                    CurrencyFormatter.localizedString(
                        from: value,
                        format: .precision,
                        sign: .never,
                        symbol: .dollarSign
                    )
                )
            case .other(let description):
                description
            }
        }
        
        init(error: Error, intent: Intent, marginSymbol: String?) {
            guard case let .response(error) = error as? MixinAPIError else {
                self = .other(description: error.localizedDescription)
                return
            }
            switch error {
            case .exceedsMaxRemovableMargin:
                if case let .string(value) = error.extra?.value(at: ["available_margin"]),
                   let decimalValue = Decimal(string: value, locale: .enUSPOSIX)
                {
                    self = .exceedsMaxRemovableMargin(decimalValue)
                } else {
                    self = .other(description: error.localizedDescription)
                }
            case .perpPositionSizeExceedsLeverageLimit:
                let maxAmount: Decimal
                if case let .string(value) = error.extra?.value(at: ["max_amount"]),
                   let decimalValue = Decimal(string: value, locale: .enUSPOSIX)
                {
                    maxAmount = decimalValue
                } else {
                    maxAmount = 0
                }
                let description: String
                switch intent {
                case .open:
                    if maxAmount > 0, let symbol = marginSymbol {
                        let amount = CurrencyFormatter.localizedString(
                            from: maxAmount,
                            format: .precision,
                            sign: .never,
                            symbol: .custom(symbol),
                        )
                        description = R.string.localizable.error_perps_position_size_exceeds_leverage_limit_value(amount)
                    } else {
                        description = R.string.localizable.error_perps_position_size_exceeds_leverage_limit()
                    }
                case .edit:
                    if maxAmount > 0, let symbol = marginSymbol {
                        let amount = CurrencyFormatter.localizedString(
                            from: maxAmount,
                            format: .precision,
                            sign: .never,
                            symbol: .custom(symbol),
                        )
                        description = R.string.localizable.error_perps_position_size_exceeds_leverage_limit_add(amount)
                    } else {
                        description = R.string.localizable.error_perps_position_size_exceeds_leverage_limit_cannot_add()
                    }
                }
                self = .other(description: description)
            default:
                self = .other(description: error.localizedDescription)
            }
        }
        
    }
    
    fileprivate let debounceInterval: UInt64 = 500 // In msec
    fileprivate let failRetryInterval: UInt64 = 3 // In sec
    
    fileprivate var task: Task<Void, Error>?
    
    deinit {
        task?.cancel()
    }
    
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
        symbol: String,
        leverage: Int,
        onSuccess: @escaping @MainActor (Decimal) -> Void,
        onFailure: @escaping @MainActor (LiquidationPriceError) -> Void,
    ) {
        task?.cancel()
        task = Task { [debounceInterval, marketID, side] in
            while LoginManager.shared.isLoggedIn {
                try await Task.sleep(nanoseconds: debounceInterval * NSEC_PER_MSEC)
                try Task.checkCancellation()
                do {
                    let price = try await RouteAPI.perpsLiquidationPrice(
                        action: .open(marketID: marketID, side: side, leverage: leverage),
                        amount: amount
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        onSuccess(price)
                    }
                    return
                } catch is CancellationError {
                    // Ignore
                } catch let error as MixinAPIError where error.worthRetrying {
                    Logger.general.error(category: "OpenPerpsPosition", message: "\(error)")
                    try await Task.sleep(nanoseconds: failRetryInterval * NSEC_PER_SEC)
                } catch {
                    let error = LiquidationPriceError(error: error, intent: .open, marginSymbol: symbol)
                    await MainActor.run {
                        onFailure(error)
                    }
                    return
                }
            }
        }
    }
    
}

final class EditPerpsPositionLiquidationPriceRequester: PerpsLiquidationPriceRequester {
    
    enum Action {
        case increasePosition
        case increaseMargin
        case decreaseMargin
    }
    
    private let action: RouteAPI.LiquidationPriceAction
    
    init(positionID: String, action: Action) {
        self.action = switch action {
        case .increasePosition:
                .increasePosition(positionID: positionID)
        case .increaseMargin:
                .increaseMargin(positionID: positionID)
        case .decreaseMargin:
                .decreaseMargin(positionID: positionID)
        }
    }
    
    @MainActor
    func request(
        amount: Decimal,
        symbol: String?,
        onSuccess: @escaping @MainActor (Decimal) -> Void,
        onFailure: @escaping @MainActor (LiquidationPriceError) -> Void,
    ) {
        task?.cancel()
        task = Task { [debounceInterval, action] in
            while LoginManager.shared.isLoggedIn {
                try await Task.sleep(nanoseconds: debounceInterval * NSEC_PER_MSEC)
                try Task.checkCancellation()
                do {
                    let price = try await RouteAPI.perpsLiquidationPrice(
                        action: action,
                        amount: amount
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        onSuccess(price)
                    }
                    return
                } catch is CancellationError {
                    // Ignore
                } catch let error as MixinAPIError where error.worthRetrying {
                    Logger.general.error(category: "AddPerpsPosition", message: "\(error)")
                    try await Task.sleep(nanoseconds: failRetryInterval * NSEC_PER_SEC)
                } catch {
                    let error = LiquidationPriceError(error: error, intent: .edit, marginSymbol: symbol)
                    await MainActor.run {
                        onFailure(error)
                    }
                    return
                }
            }
        }
    }
    
}
