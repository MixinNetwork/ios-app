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
            
            let price = derivePrice(sendToken: _sendToken, receiveToken: _receiveToken)
            if price != _price {
                _price = price
                _displayPrice = displayPrice(price: price, unit: _priceUnit)
                updates.append(.displayPrice(_displayPrice))
            }
            
            if _priceUnit == .send {
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
                _price = sendAmount / receiveAmount
                _displayPrice = displayPrice(price: _price, unit: _priceUnit)
                updates.append(.displayPrice(_displayPrice))
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
            
            let price = derivePrice(sendToken: _sendToken, receiveToken: _receiveToken)
            if price != _price {
                _price = price
                _displayPrice = displayPrice(price: price, unit: _priceUnit)
                updates.append(.displayPrice(_displayPrice))
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
            _displayPrice = displayPrice(price: _price, unit: _priceUnit)
            
            let priceEquation = priceEquation()
            let updates: [Update] = [
                .displayPrice(_displayPrice),
                .priceToken(priceToken),
                .priceEquation(priceEquation),
            ]
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    // Always `receive / send`
    var price: Decimal? {
        get {
            _price
        }
        set {
            _price = newValue
            _displayPrice = displayPrice(price: _price, unit: _priceUnit)
            
            var updates: [Update] = [
                .displayPrice(_displayPrice),
                .priceEquation(priceEquation()),
            ]
            
            let receiveAmount = calculateReceiveAmount()
            if _receiveAmount != receiveAmount {
                _receiveAmount = receiveAmount
                updates.append(.receiveAmount(receiveAmount))
            }
            
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    // Based on `priceUnit`
    var displayPrice: String? {
        get {
            _displayPrice
        }
        set {
            if let newValue,
               let price = Decimal(string: newValue, locale: .current),
               price != 0
            {
                _price = switch _priceUnit {
                case .send:
                    price
                case .receive:
                    1 / price
                }
            } else {
                _price = nil
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
    private var _price: Decimal? // Always `receive / send`
    private var _displayPrice: String?
    
    func derivePrice(
        sendToken: BalancedSwapToken?,
        receiveToken: BalancedSwapToken?
    ) -> Decimal? {
        guard
            let sendPrice = sendToken?.decimalUSDPrice,
            sendPrice != 0,
            let receivePrice = receiveToken?.decimalUSDPrice,
            receivePrice != 0
        else {
            return nil
        }
        return receivePrice / sendPrice
    }
    
    func priceEquation() -> String? {
        guard
            let sendSymbol = _sendToken?.symbol,
            let receiveSymbol = _receiveToken?.symbol,
            let price = _price,
            price != 0
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
    
    func swapSendingReceiving() {
        swap(&_sendToken, &_receiveToken)
        var updates: [Update] = []
        
        let price = derivePrice(sendToken: _sendToken, receiveToken: _receiveToken)
        if price != _price {
            _price = price
            _displayPrice = displayPrice(price: price, unit: _priceUnit)
            updates.append(.displayPrice(_displayPrice))
        }
        
        switch priceUnit {
        case .send:
            updates.append(.priceToken(_sendToken))
        case .receive:
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
    
    private func calculateReceiveAmount() -> Decimal? {
        guard
            let sendAmount = _sendAmount,
            let price = _price,
            price != 0
        else {
            return nil
        }
        return sendAmount / price
    }
    
    private func displayPrice(
        price: Decimal?,
        unit: SwapQuote.PriceUnit
    ) -> String? {
        if let price, price != 0 {
            let value = switch unit {
            case .send:
                price
            case .receive:
                1 / price
            }
            return NumberFormatter.userInputAmountSimulation.string(decimal: value)
        } else {
            return nil
        }
    }
    
}
