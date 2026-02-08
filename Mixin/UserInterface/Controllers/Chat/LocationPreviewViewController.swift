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
    private lazy var googleMapUrl: URL? = {
        guard var components = URLComponents(string: "comgooglemaps://") else {
            return nil
        }
        let center = "\(location.prettyLatitude),\(location.prettyLongitude)"
        components.queryItems = [
            URLQueryItem(name: "q", value: center),
            URLQueryItem(name: "center", value: center),
        ]
        return components.url
    }()
    
    // https://lbs.amap.com/api/amap-mobile/guide/ios/marker
    private lazy var amapUrl: URL? = {
        guard var components = URLComponents(string: "iosamap://viewMap") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "sourceApplication", value: String.mixin),
            URLQueryItem(name: "poiname", value: location.name ?? R.string.localizable.unnamed_location()),
            URLQueryItem(name: "lat", value: location.prettyLatitude),
            URLQueryItem(name: "lon", value: location.prettyLongitude),
            URLQueryItem(name: "dev", value: "0"),
        ]
        return components.url
    }()
    
    private var location: Location!
    
    convenience init(location: Location) {
        self.init(nib: R.nib.locationView)
        self.location = location
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.location()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_open_external(),
            target: self,
            action: #selector(openLocationInExternalMapApp)
        )
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
    
    @objc private func openLocationInExternalMapApp() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if let url = googleMapUrl, UIApplication.shared.canOpenURL(url) {
            sheet.addAction(UIAlertAction(title: R.string.localizable.open_in_google_maps(), style: .default, handler: { (_) in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }))
        }
        if let url = amapUrl, UIApplication.shared.canOpenURL(url) {
            sheet.addAction(UIAlertAction(title: R.string.localizable.open_in_gaode_maps(), style: .default, handler: { (_) in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.open_in_maps(), style: .default, handler: { (_) in
            self.location.mapItem.openInMaps(launchOptions: nil)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
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
        cell?.subtitleLabel.text = R.string.localizable.location_distance(distanceRepresentation)
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
