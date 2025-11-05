import Foundation
import MixinServices

final class SwapPricingModel {
    
    enum Update {
        case receiveAmount(Decimal?)
        case displayPrice(String?) // Based on `priceUnit`
        case priceToken(BalancedSwapToken?)
        case priceEquation(String?)
    }
    
    protocol Delegate: AnyObject {
        func swapPricingModel(_ model: SwapPricingModel, didUpdate updates: [Update])
    }
    
    enum Price: Equatable {
        
        // Recalculate automatically when token or amount changed
        case volatile(Decimal)
        
        // Usually comes from user input, only changes if user inputs again
        case nonVolatile(Decimal)
        
        var value: Decimal {
            switch self {
            case .volatile(let value):
                value
            case .nonVolatile(let value):
                value
            }
        }
        
        var localizedValue: String? {
            NumberFormatter
                .userInputAmountSimulation
                .string(decimal: value)
        }
        
        static func derive(
            sendToken: BalancedSwapToken?,
            receiveToken: BalancedSwapToken?
        ) -> Price? {
            guard
                let sendPrice = sendToken?.decimalUSDPrice,
                sendPrice != 0,
                let receivePrice = receiveToken?.decimalUSDPrice,
                receivePrice != 0
            else {
                return nil
            }
            let value = receivePrice / sendPrice
            return .volatile(value)
        }
        
        func reciprocal() -> Price {
            switch self {
            case .volatile(let value):
                    .volatile(1 / value)
            case .nonVolatile(let value):
                    .nonVolatile(1 / value)
            }
        }
        
    }
    
    weak var delegate: Delegate?
    
    var sendAmount: Decimal? {
        get {
            _sendAmount
        }
        set {
            _sendAmount = newValue
            let receiveAmount = calculateReceiveAmount()
            if _receiveAmount != receiveAmount {
                _receiveAmount = receiveAmount
                delegate?.swapPricingModel(self, didUpdate: [.receiveAmount(receiveAmount)])
            }
        }
    }
    
    var sendToken: BalancedSwapToken? {
        get {
            _sendToken
        }
        set {
            _sendToken = newValue
            var updates: [Update] = []
            
            switch _price {
            case .nonVolatile:
                break
            case .volatile, .none:
                let price: Price? = .derive(sendToken: _sendToken, receiveToken: _receiveToken)
                if price != _price {
                    _price = price
                    updates.append(.displayPrice(displayPrice?.localizedValue))
                }
            }
            
            if priceUnit == .send {
                updates.append(.priceToken(_sendToken))
            }
            
            let priceEquation = priceEquation()
            updates.append(.priceEquation(priceEquation))
            
            let receiveAmount = calculateReceiveAmount()
            if _receiveAmount != receiveAmount {
                _receiveAmount = receiveAmount
                updates.append(.receiveAmount(receiveAmount))
            }
            
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    var receiveAmount: Decimal? {
        get {
            _receiveAmount
        }
        set {
            _receiveAmount = newValue
            var updates: [Update] = []
            
            if let sendAmount, let receiveAmount = newValue {
                let price: Price = .volatile(sendAmount / receiveAmount)
                _price = price
                updates.append(.displayPrice(displayPrice?.localizedValue))
            }
            
            let priceEquation = priceEquation()
            updates.append(.priceEquation(priceEquation))
            
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    var receiveToken: BalancedSwapToken? {
        get {
            _receiveToken
        }
        set {
            _receiveToken = newValue
            var updates: [Update] = []
            
            switch _price {
            case .nonVolatile:
                break
            case .volatile, .none:
                let price: Price? = .derive(sendToken: _sendToken, receiveToken: _receiveToken)
                if price != _price {
                    _price = price
                    updates.append(.displayPrice(displayPrice?.localizedValue))
                }
            }
            
            if priceUnit == .receive {
                updates.append(.priceToken(_receiveToken))
            }
            
            let priceEquation = priceEquation()
            updates.append(.priceEquation(priceEquation))
            
            let receiveAmount = calculateReceiveAmount()
            if _receiveAmount != receiveAmount {
                _receiveAmount = receiveAmount
                updates.append(.receiveAmount(receiveAmount))
            }
            
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    var priceUnit: SwapQuote.PriceUnit {
        get {
            _priceUnit
        }
        set {
            _priceUnit = newValue
            
            let priceEquation = priceEquation()
            let updates: [Update] = [
                .displayPrice(displayPrice?.localizedValue),
                .priceToken(priceToken),
                .priceEquation(priceEquation),
            ]
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    // Based on `priceUnit`
    var displayPrice: Price? {
        get {
            switch _priceUnit {
            case .send:
                _price
            case .receive:
                _price?.reciprocal()
            }
        }
        set {
            _price = switch _priceUnit {
            case .send:
                newValue
            case .receive:
                newValue?.reciprocal()
            }
            
            let priceEquation = priceEquation()
            var updates: [Update] = [
                .priceEquation(priceEquation)
            ]
            
            let receiveAmount = calculateReceiveAmount()
            if _receiveAmount != receiveAmount {
                _receiveAmount = receiveAmount
                updates.append(.receiveAmount(receiveAmount))
            }
            
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    var priceToken: BalancedSwapToken? {
        switch _priceUnit {
        case .send:
            _sendToken
        case .receive:
            _receiveToken
        }
    }
    
    private var _sendAmount: Decimal?
    private var _sendToken: BalancedSwapToken?
    private var _receiveAmount: Decimal?
    private var _receiveToken: BalancedSwapToken?
    private var _priceUnit: SwapQuote.PriceUnit = .send
    private var _price: Price? // Always `send / receive`, using `send` as unit
    
    private func calculateReceiveAmount() -> Decimal? {
        guard let sendAmount = _sendAmount, let price = _price?.value else {
            return nil
        }
        return sendAmount / price
    }
    
    func priceEquation() -> String? {
        guard
            let sendSymbol = _sendToken?.symbol,
            let receiveSymbol = _receiveToken?.symbol,
            let price = _price?.value
        else {
            return nil
        }
        return SwapQuote.priceRepresentation(
            sendAmount: price,
            sendSymbol: sendSymbol,
            receiveAmount: 1,
            receiveSymbol: receiveSymbol,
            unit: _priceUnit
        )
    }
    
    func togglePriceUnit() {
        priceUnit = _priceUnit.toggled()
    }
    
}
