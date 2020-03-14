import UIKit
import MapKit

class LocationViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: TableHeaderBypassTableView!
    
    var tableViewMaskHeight: CGFloat {
        get {
            tableViewMaskLayer.frame.height
        }
        set {
            let y = view.bounds.height - newValue + tableView.contentOffset.y
            tableViewMaskLayer.frame = CGRect(x: 0, y: y, width: tableView.bounds.width, height: newValue)
            mapView.layoutMargins.bottom = newValue
        }
    }
    
    private let tableHeaderView = UIView()
    private let tableViewMaskLayer = AnimationsDisabledLayer()
    
    private var lastViewHeight: CGFloat = 0
    
    private var minTableWrapperHeight: CGFloat {
        view.bounds.height / 2
    }
    
    private var maxTableWrapperHeight: CGFloat {
        view.bounds.height - 160
    }
    
    convenience init() {
        self.init(nib: R.nib.locationView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.locationCell)
        tableViewMaskLayer.cornerRadius = 13
        tableViewMaskLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableViewMaskLayer.masksToBounds = true
        tableViewMaskLayer.backgroundColor = UIColor.black.cgColor
        tableView.layer.mask = tableViewMaskLayer
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.height != lastViewHeight {
            tableViewMaskHeight = view.bounds.height - minTableWrapperHeight
            tableHeaderView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: minTableWrapperHeight)
            tableView.tableHeaderView = tableHeaderView
            lastViewHeight = view.bounds.height
        }
    }
    
}

extension LocationViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let tableViewContentTop = tableView.convert(CGPoint.zero, to: view).y + tableHeaderView.frame.height
        var preferredWrapperHeight = view.bounds.height - tableViewContentTop
        preferredWrapperHeight = min(preferredWrapperHeight, maxTableWrapperHeight)
        tableViewMaskHeight = preferredWrapperHeight
    }
    
}
