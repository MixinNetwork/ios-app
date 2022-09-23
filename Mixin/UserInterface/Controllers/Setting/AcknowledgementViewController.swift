import UIKit

class AcknowledgementViewController: UIViewController {
    
    let acknowledgement: Acknowledgement
    
    init(acknowledgement: Acknowledgement) {
        self.acknowledgement = acknowledgement
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let textView = UITextView()
        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.bottom.equalTo(view.safeAreaLayoutGuide)
            make.left.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-8)
        }
        textView.backgroundColor = R.color.background_secondary()
        textView.textColor = R.color.text()
        textView.layer.cornerRadius = 6
        textView.clipsToBounds = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.alwaysBounceVertical = true
        textView.text = acknowledgement.content
    }
    
}
