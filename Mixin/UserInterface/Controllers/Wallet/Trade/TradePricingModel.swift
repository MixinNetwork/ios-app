import Foundation
import MixinServices

final class TradePricingModel {
    
    enum Update {
        case receiveAmount(Decimal?)
        case displayPrice(String?)
        case priceToken(BalancedSwapToken?)
        case priceEquation(String?)
    }
    
    protocol Delegate: AnyObject {
        func swapPricingModel(_ model: TradePricingModel, didUpdate updates: [Update])
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
                _displayPrice = displayPrice(price: price, numraire: _displayPriceNumeraire)
                updates.append(.displayPrice(_displayPrice))
            }
            
            if _displayPriceNumeraire == .receive {
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
                _price = receiveAmount / sendAmount
                _displayPrice = displayPrice(price: _price, numraire: _displayPriceNumeraire)
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
                _displayPrice = displayPrice(price: price, numraire: _displayPriceNumeraire)
                updates.append(.displayPrice(_displayPrice))
            }
            
            if displayPriceNumeraire == .send {
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
    
    // Always `receive / send`
    var price: Decimal? {
        get {
            _price
        }
        set {
            _price = newValue
            _displayPrice = displayPrice(price: _price, numraire: _displayPriceNumeraire)
            
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
    
    var displayPriceNumeraire: ExchangeRateQuote.Numeraire {
        get {
            _displayPriceNumeraire
        }
        set {
            _displayPriceNumeraire = newValue
            _displayPrice = displayPrice(price: _price, numraire: newValue)
            
            let priceEquation = priceEquation()
            let updates: [Update] = [
                .displayPrice(_displayPrice),
                .priceToken(priceToken),
                .priceEquation(priceEquation),
            ]
            delegate?.swapPricingModel(self, didUpdate: updates)
        }
    }
    
    // Based on `displayPriceNumeraire`
    var displayPrice: String? {
        get {
            _displayPrice
        }
        set {
            if let newValue,
               let price = Decimal(string: newValue, locale: .current),
               price != 0
            {
                _price = switch _displayPriceNumeraire {
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
        switch _displayPriceNumeraire {
        case .send:
            _receiveToken
        case .receive:
            _sendToken
        }
    }
    
    private var _sendAmount: Decimal?
    private var _sendToken: BalancedSwapToken?
    private var _receiveAmount: Decimal?
    private var _receiveToken: BalancedSwapToken?
    
    // sendToken.usdPrice / receiveToken.usdPrice
    // receiveAmount / sendAmount
    // 1 SEND = _price RECEIVE
    // 1 RECEIVE = 1 / _price SEND
    private var _price: Decimal?
    
    private var _displayPriceNumeraire: ExchangeRateQuote.Numeraire = .send
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
        return sendPrice / receivePrice
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
        return ExchangeRateQuote.expression(
            sendAmount: 1,
            sendSymbol: sendSymbol,
            receiveAmount: price,
            receiveSymbol: receiveSymbol,
            numeraire: _displayPriceNumeraire
        )
    }
    
    func swapSendingReceiving() {
        swap(&_sendToken, &_receiveToken)
        var updates: [Update] = []
        
        let price = derivePrice(sendToken: _sendToken, receiveToken: _receiveToken)
        if price != _price {
            _price = price
            _displayPrice = displayPrice(price: price, numraire: _displayPriceNumeraire)
            updates.append(.displayPrice(_displayPrice))
        }
        
        switch _displayPriceNumeraire {
        case .send:
            updates.append(.priceToken(_receiveToken))
        case .receive:
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
    
    func prepareForReuse() {
        _sendAmount = nil
        _receiveAmount = nil
        _price = nil
        _displayPrice = nil
        let updates: [Update] = [
            .receiveAmount(nil),
            .displayPrice(nil),
            .priceEquation(nil),
        ]
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
        return sendAmount * price
    }
    
    private func displayPrice(
        price: Decimal?,
        numraire: ExchangeRateQuote.Numeraire
    ) -> String? {
        if let price, price != 0 {
            let value = switch numraire {
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
