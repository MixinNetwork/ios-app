import UIKit
import WebKit

class CaptchaViewController: UIViewController {
    
    let navigationBar = UINavigationBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        navigationBar.delegate = self
        let navigationItem = UINavigationItem()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(cancelAction(_:)))
        navigationBar.items = [navigationItem]
        view.addSubview(navigationBar)
        navigationBar.snp.makeConstraints { (make) in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
        }
    }
    
    @objc func cancelAction(_ sender: Any) {
        dismiss(animated: true) {
            CaptchaManager.shared.cancel()
        }
    }
    
    func load(webView: WKWebView) {
        loadViewIfNeeded()
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }
    }
    
}

extension CaptchaViewController: UINavigationBarDelegate {
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
    
}
