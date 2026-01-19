import Foundation
import GRDB

public final class Web3OutputDAO: Web3DAO {
    
    public static let shared = Web3OutputDAO()
    
    public func outputs(token: Web3Token?) -> [Web3Output] {
        if let token {
            db.select(
                with: """
                SELECT *
                FROM outputs o
                    INNER JOIN addresses a ON o.address = a.destination
                WHERE a.wallet_id = ? AND a.chain_id = ? AND asset_id = ?
                ORDER BY created_at ASC
                """,
                arguments: [token.walletID, token.chainID, token.assetID]
            )
        } else {
            db.select(with: "SELECT * FROM outputs ORDER BY created_at ASC")
        }
    }
    
    public func unspentOutputs(address: String, assetID: String) -> [Web3Output] {
        db.select(
            with: """
            SELECT *
            FROM outputs
            WHERE address = ? AND asset_id = ? AND status = ?
            ORDER BY created_at ASC
            """,
            arguments: [address, assetID, Web3Output.Status.unspent.rawValue]
        )
    }
    
    public func availableBalance(address: String, assetID: String, db: GRDB.Database) throws -> String {
        let unspentAmounts = try String.fetchAll(
            db,
            sql: "SELECT amount FROM outputs WHERE address = ? AND asset_id = ? AND status = ?",
            arguments: [address, assetID, Web3Output.Status.unspent.rawValue]
        )
        let total: Decimal = unspentAmounts
            .compactMap { amount in
                Decimal(string: amount, locale: .enUSPOSIX)
            }
            .reduce(0, +)
        return TokenAmountFormatter.string(from: total)
    }
    
    public func replaceOutputsSkippingSignedOnes(
        walletID: String,
        address: String,
        assetID: String,
        outputs: [Web3Output],
    ) {
        db.write { db in
            let signedOutputIDs: Set<String> = try {
                let query: GRDB.SQL = "SELECT output_id FROM outputs WHERE output_id IN \(outputs.map(\.id)) AND status = 'signed'"
                let (sql, arguments) = try query.build(db)
                let ids = try String.fetchAll(db, sql: sql, arguments: arguments)
                return Set(ids)
            }()
            try db.execute(
                sql: "DELETE FROM outputs WHERE address = ? AND asset_id = ? AND status != ?",
                arguments: [address, assetID, Web3Output.Status.unspent.rawValue]
            )
            let outputsToSave = outputs.filter { output in
                !signedOutputIDs.contains(output.id)
            }
            try outputsToSave.save(db)
            try Web3TokenDAO.shared.updateAmountByOutputs(
                walletID: walletID,
                address: address,
                assetID: assetID,
                db: db,
                postTokenChangeNofication: true,
            )
        }
    }
    
    public func sign(outputIDs: [String], save changeOutput: Web3Output?, db: GRDB.Database) throws {
        let query: GRDB.SQL = "UPDATE outputs SET status = 'signed' WHERE output_id IN \(outputIDs)"
        let (sql, arguments) = try query.build(db)
        try db.execute(sql: sql, arguments: arguments)
        try changeOutput?.save(db)
    }
    
    public func delete(id: String, db: GRDB.Database) throws {
        try db.execute(sql: "DELETE FROM outputs WHERE output_id = ?", arguments: [id])
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM outputs")
    }
    
}
