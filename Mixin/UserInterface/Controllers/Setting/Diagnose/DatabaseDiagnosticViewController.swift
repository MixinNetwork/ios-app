import UIKit
import GRDB
import MixinServices

class DatabaseDiagnosticViewController: UIViewController {
    
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var outputTextView: UITextView!
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.DatabaseDiagnose")
    
    @IBAction func run(_ sender: Any) {
        AppDelegate.current.mainWindow.endEditing(true)
        let sql = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        queue.async {
            guard sql.prefix(6).uppercased() == "SELECT" else {
                DispatchQueue.main.sync {
                    self.outputTextView.text = "Only select statements are supported"
                }
                return
            }
            let output: String
            do {
                output = try UserDatabase.current.pool.read { db in
                    var rows: [String] = []
                    let cursor = try Row.fetchCursor(db, sql: sql)
                    while let row = try cursor.next() {
                        rows.append(row.description)
                    }
                    return rows.joined(separator: "\n")
                }
            } catch {
                output = "\(error)"
            }
            DispatchQueue.main.sync {
                self.outputTextView.text = output
            }
        }
    }
    
    @IBAction func pasteInput(_ sender: Any) {
        inputTextView.text = UIPasteboard.general.string
    }
    
    @IBAction func copyOutput(_ sender: Any) {
        UIPasteboard.general.string = outputTextView.text
    }
    
}
