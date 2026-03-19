import Foundation
import MixinServices

final class PerpetualCandleLoader {
    
    protocol Delegate: AnyObject {
        
        func perpetualCandleLoader(
            _ loader: PerpetualCandleLoader,
            didLoadCandles candles: [PerpetualCandleViewModel]?, // nil value for bad remote data
            forTimeFrame timeFrame: PerpetualTimeFrame
        )
        
    }
    
    weak var delegate: Delegate?
    
    private let marketID: String
    
    private weak var timer: Timer?
    
    init(marketID: String) {
        self.marketID = marketID
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start(timeFrame: PerpetualTimeFrame) {
        assert(Thread.isMainThread)
        timer?.invalidate()
        let timer: Timer = .scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [marketID, weak self] (timer) in
            RouteAPI.perpsMarketCandles(
                marketID: marketID,
                timeFrame: timeFrame,
                queue: .global(),
            ) { result in
                switch result {
                case .success(let candle):
                    let candles = PerpetualCandleViewModel.viewModels(
                        timeFrame: timeFrame,
                        candle: candle
                    )
                    DispatchQueue.main.async {
                        guard let self else {
                            timer.invalidate()
                            return
                        }
                        self.delegate?.perpetualCandleLoader(
                            self,
                            didLoadCandles: candles,
                            forTimeFrame: timeFrame
                        )
                    }
                case .failure(let error):
                    Logger.general.debug(category: "PerpCandleLoader", message: "\(error)")
                }
            }
        }
        self.timer = timer
        timer.fire()
    }
    
    func stop() {
        assert(Thread.isMainThread)
        timer?.invalidate()
        timer = nil
    }
    
}
