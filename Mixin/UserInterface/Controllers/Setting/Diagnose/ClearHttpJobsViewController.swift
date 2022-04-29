import UIKit
import GRDB
import MixinServices

class ClearHttpJobsViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        MixinService.isStopProcessMessages = false
        WebSocketService.shared.connectIfNeeded()
    }
    
    @IBAction func clearHttpJobs(_ sender: Any) {
        MixinService.isStopProcessMessages = true
        WebSocketService.shared.disconnect()
        textView.text += "Start clearing jobs...\n"
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
            do {
                while true {
                    let nextOrderId: Int? = try UserDatabase.current.writeAndReturnError { db in
                        let delete = """
                        DELETE FROM jobs WHERE orderId in (
                            SELECT orderId FROM jobs WHERE category = 'Http' LIMIT 1000
                        )
                        """
                        try db.execute(sql: delete)
                        return try Job
                            .select(Job.column(of: .orderId))
                            .filter(Job.column(of: .category) == JobCategory.Http.rawValue)
                            .order([Job.column(of: .priority).desc, Job.column(of: .orderId).asc])
                            .fetchOne(db)
                    }
                    if let nextOrderId = nextOrderId {
                        DispatchQueue.main.async {
                            self?.textView.text += "Next id: \(nextOrderId)\n"
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.textView.text += "All Http jobs are cleared\n"
                        }
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.textView.text += "Error: \(error)\n"
                }
            }
        }
    }
    
}
