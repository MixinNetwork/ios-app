#if DEBUG
import UIKit

public enum TIPDiagnostic {
    
    @MainActor
    public static var failLastSignerOnce = false {
        didSet {
            updateDashboard()
        }
    }
    
    @MainActor
    public static var failPINUpdateServerSideOnce = false {
        didSet {
            updateDashboard()
        }
    }
    
    @MainActor
    public static var failPINUpdateClientSideOnce = false {
        didSet {
            updateDashboard()
        }
    }
    
    @MainActor
    public static var failCounterWatchOnce = false {
        didSet {
            updateDashboard()
        }
    }
    
    @MainActor
    public static var uiTestOnly = false {
        didSet {
            updateDashboard()
        }
    }
    
    @MainActor
    public static var crashAfterUpdatePIN = false {
        didSet {
            updateDashboard()
        }
    }
    
    private static let dashboardLabel: UITextView = {
        let textView = UITextView()
        textView.alpha = 0.45
        textView.textColor = .white
        textView.textAlignment = .right
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .black
        textView.isUserInteractionEnabled = false
        textView.layer.zPosition = .greatestFiniteMagnitude
        textView.isScrollEnabled = false
        let sharedApplication = NSSelectorFromString("sharedApplication")
        if UIApplication.responds(to: sharedApplication) {
            let application = UIApplication.perform(sharedApplication).takeUnretainedValue() as! UIApplication
            if let window = application.keyWindow {
                window.addSubview(textView)
                textView.translatesAutoresizingMaskIntoConstraints = false
                let constraints = [
                    textView.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor),
                    textView.trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -20)
                ]
                NSLayoutConstraint.activate(constraints)
            }
        }
        return textView
    }()
    
    @MainActor
    private static func updateDashboard() {
        Self.dashboardLabel.text = """
        Fail Last Sign: \(failLastSignerOnce ? "ONCE" : " OFF")
        Fail PIN Update Server: \(failPINUpdateServerSideOnce ? "ONCE" : " OFF")
        Fail PIN Update Client: \(failPINUpdateClientSideOnce ? "ONCE" : " OFF")
        Fail Watch: \(failCounterWatchOnce ? "ONCE" : " OFF")
        Crash After PIN Update: \(crashAfterUpdatePIN ? "  ON" : " OFF")
        UI Test: \(uiTestOnly ? "  ON" : " OFF")
        """
    }
    
}
#endif
