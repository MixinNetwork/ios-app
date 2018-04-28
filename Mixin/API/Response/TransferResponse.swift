import Foundation

struct TransferResponse: Codable {

    let type: String
    let transfer_id: String
    let counter_user_id: String
    let asset_id: String
    let amount: String
    let created_at: String

}
