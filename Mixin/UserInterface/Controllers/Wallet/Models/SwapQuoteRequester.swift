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
    
    let refreshInterval = 10
    
    var countDownIncludesZero = true
    
    weak var delegate: SwapQuotePeriodicRequesterDelegate?
    
    private let request: QuoteRequest
    private let quote: SwapQuote
    
    private var isRunning = false
    private var nextQuoteCountDown = 0
    
    private weak var lastRequest: Request?
    private weak var timer: Timer?
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<SwapQuotePeriodicRequester>.passUnretained(self).toOpaque()
    }
    
    init(
        sendToken: TokenItem, sendAmount: Decimal,
        receiveToken: SwappableToken, slippage: Decimal
    ) {
        self.request = QuoteRequest.exin(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken,
            slippage: slippage
        )
        self.quote = SwapQuote(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken,
            receiveAmount: 0
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
    
    private func requestQuote() {
        timer?.invalidate()
        delegate?.swapQuotePeriodicRequesterWillUpdate(self)
        Logger.general.debug(category: "SwapQuote", message: "\(opaquePointer) Request quote")
        lastRequest = RouteAPI.quote(request: request) { [weak self, quote] result in
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
                let newQuote = quote.updated(receiveAmount: receiveAmount)
                self.delegate?.swapQuotePeriodicRequester(self, didUpdate: .success(newQuote))
                self.scheduleCountDownTimer()
            case .failure(.httpTransport(.explicitlyCancelled)):
                break
            case .failure(let error):
                self.delegate?.swapQuotePeriodicRequester(self, didUpdate: .failure(error))
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