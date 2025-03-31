import Foundation
import Alamofire
import MixinServices

protocol SwapQuotePeriodicRequesterDelegate: AnyObject {
    func swapQuotePeriodicRequesterWillUpdate(_ requester: SwapQuotePeriodicRequester)
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didUpdate result: Result<SwapQuote, Error>)
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didCountDown value: Int)
}

final class SwapQuotePeriodicRequester {
    
    enum RequestError: Error {
        case invalidResponseAmount(String)
    }
    
    enum ResponseError: Error {
        case invalidAmount(AmountRange)
    }
    
    let refreshInterval = 10
    
    var countDownIncludesZero = true
    
    weak var delegate: SwapQuotePeriodicRequesterDelegate?
    
    private let request: QuoteRequest
    private let quoteDraft: SwapQuoteDraft
    
    private var isRunning = false
    private var nextQuoteCountDown = 0
    
    private weak var lastRequest: Request?
    private weak var timer: Timer?
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<SwapQuotePeriodicRequester>.passUnretained(self).toOpaque()
    }
    
    init(
        sendToken: BalancedSwapToken, sendAmount: Decimal,
        receiveToken: SwapToken, slippage: Decimal
    ) {
        self.request = QuoteRequest.mixin(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken,
            slippage: slippage
        )
        self.quoteDraft = SwapQuoteDraft(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken
        )
    }
    
    func start(delay: TimeInterval) {
        guard !isRunning else {
            return
        }
        Logger.general.debug(category: "SwapQuote", message: "\(opaquePointer) Start")
        isRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isRunning else {
                return
            }
            self.requestQuote()
        }
    }
    
    func stop() {
        Logger.general.info(category: "SwapQuote", message: "\(opaquePointer) Stop")
        isRunning = false
        lastRequest?.cancel()
        timer?.invalidate()
    }
    
}

extension SwapQuotePeriodicRequester {
    
    struct AmountRange {
        
        let minimum: Decimal?
        let maximum: Decimal?
        let description: String
        
        init?(extra: MixinAPIResponseError.JSON, symbol: String) {
            let min: String?
            if case let .string(string) = extra.value(at: ["data", "min"]),
               let decimal = Decimal(string: string, locale: .enUSPOSIX)
            {
                self.minimum = decimal
                min = CurrencyFormatter.localizedString(
                    from: decimal,
                    format: .precision,
                    sign: .never
                )
            } else {
                self.minimum = nil
                min = nil
            }
            
            let max: String?
            if case let .string(string) = extra.value(at: ["data", "max"]),
               let decimal = Decimal(string: string, locale: .enUSPOSIX)
            {
                self.maximum = decimal
                max = CurrencyFormatter.localizedString(
                    from: decimal,
                    format: .precision,
                    sign: .never
                )
            } else {
                self.maximum = nil
                max = nil
            }
            
            switch (min, max) {
            case let (.some(min), .none):
                self.description = R.string.localizable.single_transaction_should_be_greater_than(min, symbol)
            case let (.none, .some(max)):
                self.description = R.string.localizable.single_transaction_should_be_less_than(max, symbol)
            case let (.some(min), .some(max)):
                self.description = R.string.localizable.single_transaction_should_be_between(min, symbol, max, symbol)
            default:
                return nil
            }
        }
        
    }
    
    private func requestQuote() {
        timer?.invalidate()
        delegate?.swapQuotePeriodicRequesterWillUpdate(self)
        Logger.general.debug(category: "SwapQuote", message: "\(opaquePointer) Request quote")
        lastRequest = RouteAPI.quote(request: request) { [weak self, quoteDraft] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let response):
                guard let receiveAmount = Decimal(string: response.outAmount, locale: .enUSPOSIX) else {
                    let error: RequestError = .invalidResponseAmount(response.outAmount)
                    self.delegate?.swapQuotePeriodicRequester(self, didUpdate: .failure(error))
                    return
                }
                let quote = SwapQuote(
                    draft: quoteDraft,
                    receiveAmount: receiveAmount,
                    source: response.source,
                    payload: response.payload
                )
                self.delegate?.swapQuotePeriodicRequester(self, didUpdate: .success(quote))
                self.scheduleCountDownTimer()
            case .failure(.httpTransport(.explicitlyCancelled)):
                break
            case .failure(let error):
                if case let .response(error) = error,
                   case .invalidQuoteAmount = error,
                   let extra = error.extra,
                   let range = AmountRange(extra: extra, symbol: quoteDraft.sendToken.symbol)
                {
                    let error: ResponseError = .invalidAmount(range)
                    self.delegate?.swapQuotePeriodicRequester(self, didUpdate: .failure(error))
                } else {
                    self.delegate?.swapQuotePeriodicRequester(self, didUpdate: .failure(error))
                }
            }
        }
    }
    
    private func scheduleCountDownTimer() {
        let lastCountDown = countDownIncludesZero ? -1 : 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
            guard let self else {
                timer.invalidate()
                return
            }
            let countDown = self.nextQuoteCountDown
            if countDown == lastCountDown {
                self.requestQuote()
            } else {
                self.delegate?.swapQuotePeriodicRequester(self, didCountDown: countDown)
                self.nextQuoteCountDown = countDown - 1
            }
        }
        self.timer = timer
        nextQuoteCountDown = refreshInterval + lastCountDown
        timer.fire()
    }
    
}
