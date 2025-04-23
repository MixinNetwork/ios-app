import Foundation
import MixinServices

final class RichWeb3RawTransaction: Web3RawTransaction {
    
    let simulateTransaction: TransactionSimulation?
    
    required init(from decoder: Decoder) throws {
        
        enum CodingKeys: String, CodingKey {
            case simulateTransaction = "simulate_tx"
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.simulateTransaction = try container.decodeIfPresent(
            TransactionSimulation.self,
            forKey: .simulateTransaction
        )
        try super.init(from: decoder)
    }
    
}

extension Web3Transaction {
    
    convenience init(
        rawTransaction: RichWeb3RawTransaction,
        fee: Decimal?
    ) {
        let simulation = rawTransaction.simulateTransaction
        
        let transactionFee = if let fee {
            TokenAmountFormatter.string(from: fee)
        } else {
            ""
        }
        
        var receiveChanges: [BalanceChange] = []
        var sendChanges: [BalanceChange] = []
        for change in simulation?.balanceChanges ?? [] {
            if change.amount.hasPrefix("-") {
                sendChanges.append(change)
            } else {
                receiveChanges.append(change)
            }
        }
        
        let type: TransactionType
        if let approves = simulation?.approves, !approves.isEmpty {
            type = .approval
        } else {
            switch (sendChanges.isEmpty, receiveChanges.isEmpty) {
            case (true, true):
                type = .unknown
            case (true, false):
                type = .transferIn
            case (false, true):
                type = .transferOut
            case (false, false):
                type = .swap
            }
        }
        
        let senders: [Web3Transaction.Sender]?
        let receivers: [Web3Transaction.Receiver]?
        let approvals: [Web3Transaction.Approval]?
        switch type {
        case .transferIn:
            senders = nil
            receivers = receiveChanges.map { change in
                Web3Transaction.Receiver(
                    assetID: change.assetID,
                    amount: change.amount,
                    to: nil
                )
            }
            approvals = nil
        case .transferOut:
            senders = sendChanges.map { change in
                Web3Transaction.Sender(
                    assetID: change.assetID,
                    amount: String(change.amount.dropFirst()),
                    from: nil
                )
            }
            receivers = nil
            approvals = nil
        case .swap:
            senders = sendChanges.map { change in
                Web3Transaction.Sender(
                    assetID: change.assetID,
                    amount: String(change.amount.dropFirst()),
                    from: nil
                )
            }
            receivers = receiveChanges.map { change in
                Web3Transaction.Receiver(
                    assetID: change.assetID,
                    amount: change.amount,
                    to: nil
                )
            }
            approvals = nil
        case .approval:
            senders = nil
            receivers = nil
            approvals = simulation?.approves?.map { approve in
                switch approve.amount {
                case .unlimited:
                        .init(
                            assetID: approve.assetID,
                            amount: "",
                            to: approve.spender,
                            approvalType: .unlimited
                        )
                case .limited(let value):
                        .init(
                            assetID: approve.assetID,
                            amount: TokenAmountFormatter.string(from: value),
                            to: approve.spender,
                            approvalType: .other
                        )
                }
            }
        case .unknown:
            senders = nil
            receivers = nil
            approvals = nil
        }
        
        self.init(
            transactionHash: rawTransaction.hash,
            chainID: rawTransaction.chainID,
            address: rawTransaction.account,
            transactionType: .known(type),
            status: .pending,
            blockNumber: -1,
            fee: transactionFee,
            senders: senders,
            receivers: receivers,
            approvals: approvals,
            sendAssetID: sendChanges.first?.assetID,
            receiveAssetID: receiveChanges.first?.assetID,
            transactionAt: rawTransaction.createdAt,
            createdAt: rawTransaction.createdAt,
            updatedAt: rawTransaction.createdAt
        )
    }
    
}
