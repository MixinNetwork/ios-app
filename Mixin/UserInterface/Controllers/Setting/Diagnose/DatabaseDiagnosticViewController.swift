import UIKit
import GRDB
import MixinServices

class DatabaseDiagnosticViewController: UIViewController {
    
    @IBOutlet weak var databaseSwitcher: UISegmentedControl!
    @IBOutlet weak var runButton: UIButton!
    @IBOutlet weak var pasteButton: UIButton!
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var outputTextView: UITextView!
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.DatabaseDiagnose")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        databaseSwitcher.selectedSegmentIndex = 1
        changeDatabase(self)
    }
    
    @IBAction func changeDatabase(_ sender: Any) {
        switch databaseSwitcher.selectedSegmentIndex {
        case 0:
            inputTextView.text = "SELECT * FROM identities LIMIT 10"
        case 1:
            inputTextView.text = "SELECT * FROM users LIMIT 10"
        default:
            inputTextView.text = "SELECT * FROM messages_blaze LIMIT 10"
        }
    }
    
    @IBAction func run(_ sender: Any) {
        AppDelegate.current.mainWindow.endEditing(true)
        runButton.isEnabled = false
        runButton.setTitle("Executing", for: .normal)
        pasteButton.isEnabled = false
        let sql = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let database: MixinServices.Database = {
            switch databaseSwitcher.selectedSegmentIndex {
            case 0:
                return SignalDatabase.current
            case 1:
                return UserDatabase.current
            default:
                return TaskDatabase.current
            }
        }()
        
        func execute(_ db: GRDB.Database) throws -> String {
            let startTime = CACurrentMediaTime()
            var rows: [String] = []
            let cursor = try Row.fetchCursor(db, sql: sql)
            while let row = try cursor.next() {
                rows.append(row.description)
            }
            let endTime = CACurrentMediaTime()
            return "\(rows.count) rows in \(endTime - startTime)s\n\n" + rows.joined(separator: "\n")
        }
        
        queue.async {
#if RELEASE
            let prefix = sql.prefix(6).uppercased()
            guard prefix == "SELECT" || prefix == "EXPLAI" else {
                DispatchQueue.main.sync {
                    self.outputTextView.text = "Only queries are supported"
                }
                return
            }
#endif
            let output: String
            do {
#if DEBUG
                output = try database.writeAndReturnError(execute(_:))
#else
                output = try database.read(execute(_:))
#endif
            } catch {
                output = "\(error)"
            }
            DispatchQueue.main.sync {
                self.runButton.isEnabled = true
                self.runButton.setTitle("Run", for: .normal)
                self.pasteButton.isEnabled = true
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
    
    @IBAction func cleanInput(_ sender: Any) {
        inputTextView.text = ""
        outputTextView.text = ""
    }
}
