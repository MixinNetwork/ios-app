import UIKit
import MixinServices
import MapKit

class LocationPreviewViewController: LocationViewController {
    
    override var minTableWrapperMaskHeight: CGFloat {
        tableView.rowHeight
            + tableView.sectionHeaderHeight
            + tableView.contentInset.bottom
            + view.safeAreaInsets.bottom
    }
    
    // https://developers.google.com/maps/documentation/urls/ios-urlscheme
    private lazy var googleMapUrl = URL(string: "comgooglemaps://?center=\(location.latitude),\(location.longitude)")!
    
    // https://lbs.amap.com/api/amap-mobile/guide/ios/marker
    private lazy var gaodeMapUrl: URL = {
        var components = URLComponents(string: "iosamap://viewMap")!
        components.queryItems = [
            URLQueryItem(name: "sourceApplication", value: "Mixin Messenger"),
            URLQueryItem(name: "poiname", value: location.name ?? R.string.localizable.chat_location_unnamed()),
            URLQueryItem(name: "lat", value: "\(location.latitude)"),
            URLQueryItem(name: "lon", value: "\(location.longitude)"),
            URLQueryItem(name: "dev", value: "0"),
        ]
        return components.url!
    }()
    
    private var location: Location!
    
    convenience init(location: Location) {
        self.init(nib: R.nib.locationView)
        self.location = location
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.userTrackingMode = .none
        mapView.showsUserLocation = true
        mapView.delegate = self
        let region = MKCoordinateRegion(center: location.coordinate,
                                        latitudinalMeters: 5000,
                                        longitudinalMeters: 5000)
        mapView.setRegion(region, animated: false)
        mapView.addAnnotation(location)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isScrollEnabled = false
        updateTableViewBottomInsetIfNeeded()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        resetTableWrapperMaskHeightAndHeaderView()
        updateTableViewBottomInsetIfNeeded()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openLocationInExternalMapApp()
    }
    
    private func updateTableViewBottomInsetIfNeeded() {
        if view.safeAreaInsets.bottom < 10 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func openLocationInExternalMapApp() {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIApplication.shared.canOpenURL(googleMapUrl) {
            controller.addAction(UIAlertAction(title: R.string.localizable.chat_open_external_maps_google(), style: .default, handler: { (_) in
                UIApplication.shared.open(self.googleMapUrl, options: [:], completionHandler: nil)
            }))
        }
        if UIApplication.shared.canOpenURL(gaodeMapUrl) {
            controller.addAction(UIAlertAction(title: R.string.localizable.chat_open_external_maps_gaode(), style: .default, handler: { (_) in
                UIApplication.shared.open(self.gaodeMapUrl, options: [:], completionHandler: nil)
            }))
        }
        controller.addAction(UIAlertAction(title: R.string.localizable.chat_open_external_maps_apple(), style: .default, handler: { (_) in
            self.location.mapItem.openInMaps(launchOptions: nil)
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
}

extension LocationPreviewViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        openLocationInExternalMapApp()
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_open_external()
    }
    
}

extension LocationPreviewViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is Location {
            return mapView.dequeueReusableAnnotationView(withIdentifier: pinAnnotationReuseId, for: annotation)
        } else {
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard location.address == nil else {
            return
        }
        let distance = userLocation.coordinate.distance(from: location.coordinate)
        let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? LocationCell
        let distanceRepresentation = MKDistanceFormatter.general.string(fromDistance: distance)
        cell?.subtitleLabel.text = R.string.localizable.chat_location_distance(distanceRepresentation)
    }
    
}

extension LocationPreviewViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.location, for: indexPath)!
        cell.render(location: location)
        cell.showsNavigationImageView = true
        return cell
    }
    
}
