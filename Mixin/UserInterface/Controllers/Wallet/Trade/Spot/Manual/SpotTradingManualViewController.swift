import UIKit
import SwiftUI
import Alamofire
import MixinServices

final class SpotTradingManualViewController: ManualViewController {
    
    private enum Page: Int {
        case intro
        case simple
        case advanced
    }
    
    private let refreshInterval = 10
    private let quote = SpotTradingManual.Quote()
    
    private var price: Decimal = 1
    private var isRunning = false
    private var nextQuoteCountDown = 0
    
    private weak var lastRequest: Request?
    private weak var timer: Timer?
    
    init() {
        let pages = [
            ManualViewController.Page(
                title: R.string.localizable.brief_introduction(),
                view: SpotTradingManualIntroductionPageView()
            ),
            ManualViewController.Page(
                title: R.string.localizable.trade_simple(),
                view: SpotTradingManualSimpleModePageView()
                    .environmentObject(quote)
            ),
            ManualViewController.Page(
                title: R.string.localizable.trade_advanced(),
                view: SpotTradingManualAdvancedModePageView(price: quote.price)
                    .environmentObject(quote)
            ),
        ]
        super.init(pages: pages, initialIndex: 0)
        title = R.string.localizable.spot_trading_guide()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func pageDidAppear(index: Int) {
        switch Page(rawValue: index) {
        case .intro, .none:
            stopQuoteRequest()
        case .simple, .advanced:
            startQuoteRequest()
        }
    }
    
    private func startQuoteRequest() {
        guard !isRunning else {
            return
        }
        isRunning = true
        requestQuote()
    }
    
    private func stopQuoteRequest() {
        isRunning = false
        lastRequest?.cancel()
        timer?.invalidate()
    }
    
    private func requestQuote() {
        timer?.invalidate()
        let request = QuoteRequest(
            inputMint: AssetID.btc,
            outputMint: AssetID.erc20USDC,
            amount: "1",
            slippage: Slippage(decimal: 0.01).integral,
            source: .mixin
        )
        lastRequest = RouteAPI.quote(request: request) { [weak self] result in
            guard let self, self.isRunning else {
                return
            }
            switch result {
            case .success(let response):
                if let receiveAmount = Decimal(string: response.outAmount, locale: .enUSPOSIX) {
                    self.quote.price = receiveAmount
                    self.scheduleCountDownTimer()
                }
            case .failure(let error):
                Logger.general.debug(category: "SpotTradingManual", message: "\(error)")
            }
        }
    }
    
    private func scheduleCountDownTimer() {
        let lastCountDown = -1
        let timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self, refreshInterval] (timer) in
            guard let self, self.isRunning else {
                timer.invalidate()
                return
            }
            let countDown = self.nextQuoteCountDown
            if countDown == lastCountDown {
                withAnimation(.linear(duration: 1)) {
                    self.quote.progress = 0
                }
                self.requestQuote()
            } else {
                let progress = CGFloat(countDown - lastCountDown) / CGFloat(refreshInterval)
                withAnimation(progress == 1 ? .none : .linear(duration: 1)) {
                    self.quote.progress = progress
                }
                self.nextQuoteCountDown = countDown - 1
            }
        }
        self.timer = timer
        nextQuoteCountDown = refreshInterval + lastCountDown
        timer.fire()
    }
    
}
