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
                WHERE a.wallet_id = ? AND a.chain_id = ? AND o.asset_id = ?
                ORDER BY o.created_at ASC
                """,
                arguments: [token.walletID, token.chainID, token.assetID]
            )
        } else {
            db.select(with: "SELECT * FROM outputs ORDER BY created_at ASC")
        }
    }
    
    public func outputs(ids: [String]) -> [Web3Output] {
        let query: GRDB.SQL = """
        SELECT *
        FROM outputs
        WHERE output_id IN \(ids)
        ORDER BY created_at ASC
        """
        return db.select(with: query)
    }
    
    public func outputs(
        address: String,
        assetID: String,
        status: Set<Web3Output.Status>
    ) -> [Web3Output] {
        let query: GRDB.SQL = """
        SELECT *
        FROM outputs
        WHERE address = \(address) AND asset_id = \(assetID) AND status IN \(status)
        ORDER BY created_at ASC
        """
        return db.select(with: query)
    }
    
    public func isOutputAvailable(id: String) -> Bool {
        let status: String? = db.select(
            with: "SELECT status FROM outputs WHERE output_id = ?",
            arguments: [id]
        )
        guard let value = status, let status = Web3Output.Status(rawValue: value) else {
            return false
        }
        switch status {
        case .pending, .unspent:
            return true
        case .signed:
            return false
        }
    }
    
    public func availableBalance(address: String, assetID: String, db: GRDB.Database) throws -> String {
        let unspentAmounts = try String.fetchAll(
            db,
            sql: "SELECT amount FROM outputs WHERE address = ? AND asset_id = ? AND status IN (?,?)",
            arguments: [address, assetID, Web3Output.Status.unspent.rawValue, Web3Output.Status.pending.rawValue]
        )
        let total: Decimal = unspentAmounts
            .compactMap { amount in
                Decimal(string: amount, locale: .enUSPOSIX)
            }
            .reduce(0, +)
        return TokenAmountFormatter.string(from: total)
    }
    
    public func saveUnspentOutputs(
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
            let outputsToSave = outputs.filter { output in
                // Do not override signed local outputs with unspent remote ones
                // They're already spent but not confirmed yet
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
