//
//  PerpsAutoClosingConditionTests.swift
//  Mixin
//
//  Created by wu on 2026/11/6.
//  Copyright © 2026 Mixin. All rights reserved.
//

import Testing
import TIP
@testable import Mixin
@testable import MixinServices

struct PerpsAutoClosingConditionTests {
    
    @Test(arguments: [PerpetualOrderSide.long, .short], [false, true])
    func takeProfitRejectsLossAfterFees(side: PerpetualOrderSide, isOpen: Bool) {
        let condition = makeCondition(side: side, isOpen: isOpen, feeRate: "0.001", priceScale: 3)
        let price: Decimal = side == .long ? 100.1 : 99.9
        #expect(throws: PerpsAutoClosingCondition.InvalidInputError.self) {
            try condition.setPrice(price)
        }
        #expect(condition.price == 0)
        #expect(condition.percentage == 0)
    }
    
    @Test(arguments: [PerpetualOrderSide.long, .short], ["0", "0.001"])
    func takeProfitRejectsBreakEven(side: PerpetualOrderSide, feeRate: String) {
        let condition = makeCondition(side: side, isOpen: true, feeRate: feeRate, priceScale: 3)
        let fee = Decimal(string: feeRate)!
        let breakEvenPrice = side == .long
            ? 100 * (1 + fee) / (1 - fee)
            : 100 * (1 - fee) / (1 + fee)
        do {
            try condition.setPrice(breakEvenPrice)
            Issue.record("A take-profit must be strictly profitable after fees")
        } catch {
            switch (side, error) {
            case (.long, .mustHigherThan(let boundary)), (.short, .mustLowerThan(let boundary)):
                #expect(boundary == breakEvenPrice)
            default:
                Issue.record("Unexpected validation error: \(error)")
            }
        }
    }
    
    @Test(arguments: [PerpetualOrderSide.long, .short], [false, true])
    func profitablePriceRoundTripsThroughPercentage(side: PerpetualOrderSide, isOpen: Bool) throws {
        let condition = makeCondition(side: side, isOpen: isOpen, feeRate: "0.001", priceScale: 3)
        let price: Decimal = side == .long ? 101 : 99
        try condition.setPrice(price)
        let percentage = condition.percentage
        #expect(percentage > 0)
        let expectedPercentage = Decimal(string: side == .long ? "0.0799" : "0.0801")!
        #expect(percentage == expectedPercentage)
        try condition.setPercentage(percentage)
        #expect(condition.roundedPrice(percentage: condition.percentage) == price)
    }
    
    @Test(arguments: [PerpetualOrderSide.long, .short], [Decimal(0), Decimal(string: "-0.00001")!])
    func roundingCannotMakeNonpositiveTakeProfitValid(side: PerpetualOrderSide, percentage: Decimal) {
        let condition = makeCondition(side: side, isOpen: true, feeRate: "0.00103", priceScale: 2)
        // Both prices round to a profitable tick even though the input PnL is not positive.
        #expect(throws: PerpsAutoClosingCondition.InvalidInputError.self) {
            try condition.setPercentage(percentage)
        }
    }
    
    @Test(arguments: [PerpetualOrderSide.long, .short])
    func roundingCannotTurnTakeProfitIntoLoss(side: PerpetualOrderSide) {
        let condition = makeCondition(side: side, isOpen: true, feeRate: "0.00103", priceScale: 1)
        #expect(throws: PerpsAutoClosingCondition.InvalidInputError.self) {
            try condition.setPercentage(Decimal(string: "0.00001")!)
        }
    }
    
    private func makeCondition(
        side: PerpetualOrderSide,
        isOpen: Bool,
        feeRate: String,
        priceScale: Int,
    ) -> PerpsAutoClosingCondition {
        let market = PerpetualMarket(
            marketID: "test-market",
            displaySymbol: "TEST-USDT",
            tokenSymbol: "TEST",
            quoteSymbol: "USDT",
            markPrice: "100",
            leverage: 10,
            iconURL: "",
            fundingRate: "0",
            minAmount: "1",
            maxAmount: "10000",
            last: "100",
            volume: "0",
            high: "100",
            low: "100",
            openPrice: "100",
            change: "0",
            bidPrice: "100",
            askPrice: "100",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z",
            category: .known(.crypto),
            tags: [],
            priceScale: priceScale,
            descriptions: nil,
            fundingIntervalHours: 8,
            nextFundingAt: "2026-01-01T08:00:00Z",
            openInterest: "0",
            tradeVolumeScore1D: 0,
            quantityScale: 3,
            minOrderValue: "1",
            feeRate: feeRate,
        )
        return PerpsAutoClosingCondition(
            behavior: .takeProfit,
            side: side,
            leverage: 10,
            margin: 10,
            marketViewModel: PerpetualMarketViewModel(market: market),
            orderState: isOpen ? .open(entryPrice: 100, quantity: 1) : .draft,
            liquidationPrice: side == .long ? 90 : 110,
        )
    }
    
}
