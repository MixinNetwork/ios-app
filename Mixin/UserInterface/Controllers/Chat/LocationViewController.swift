import UIKit
import MapKit

class LocationViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: TableHeaderBypassTableView!
    
    let headerReuseId = "header"
    
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
    
    var minTableWrapperHeight: CGFloat {
        view.bounds.height / 2
    }
    
    private let tableHeaderView = UIView()
    private let tableViewMaskLayer = AnimationsDisabledLayer()
    
    private var lastViewHeight: CGFloat = 0
    
    private var maxTableWrapperHeight: CGFloat {
        view.bounds.height - 160
    }
    
    convenience init() {
        self.init(nib: R.nib.locationView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.locationCell)
        tableView.register(UITableViewHeaderFooterView.self,
                           forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableViewMaskLayer.cornerRadius = 13
        tableViewMaskLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableViewMaskLayer.masksToBounds = true
        tableViewMaskLayer.backgroundColor = UIColor.black.cgColor
        tableView.layer.mask = tableViewMaskLayer
        tableView.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.height != lastViewHeight {
            updateTableViewMaskAndHeaderView()
            lastViewHeight = view.bounds.height
        }
    }
    
    func updateTableViewMaskAndHeaderView() {
        tableViewMaskHeight = minTableWrapperHeight
        let headerSize = CGSize(width: tableView.frame.width,
                                height: view.bounds.height - minTableWrapperHeight)
        tableHeaderView.frame = CGRect(origin: .zero, size: headerSize)
        tableView.tableHeaderView = tableHeaderView
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

extension LocationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? tableView.sectionHeaderHeight : .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId)!
        view.contentView.backgroundColor = .background
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
}
