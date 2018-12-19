import UIKit

class TransferAssetSearchBar: UISearchBar {
    
    private static let setTextFieldAppearance: Void = {
        let appearance = UITextField.appearance(whenContainedInInstancesOf: [TransferAssetSearchBar.self])
        appearance.defaultTextAttributes = [.font: UIFont.systemFont(ofSize: 14)]
    }()
    
    override init(frame: CGRect) {
        TransferAssetSearchBar.setTextFieldAppearance
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setShowsCancelButton(false, animated: false)
    }
    
}
