import UIKit
import CoreLocation
import MapKit
import MixinServices

class LocationPickerViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var scrollToUserLocationButton: UIButton!
    
    class func instance(conversationInputViewController: ConversationInputViewController) -> UIViewController {
        let vc = R.storyboard.chat.location_picker()!
        vc.input = conversationInputViewController
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_menu_location())
    }
    
    private let annotationReuseId = "anno"
    
    private var input: ConversationInputViewController!
    private var localSearch: MKLocalSearch?
    private var locations: [NearbyLocationLoader.Location] = []
    
    private var userLocationAccuracy: String {
        if let accuracy = mapView.userLocation.location?.horizontalAccuracy {
            if accuracy > 0 {
                return "\(accuracy)m"
            } else {
                return ">1km"
            }
        } else {
            return ">1km"
        }
    }
    
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let imageView = scrollToUserLocationButton.imageView {
            imageView.contentMode = .center
            imageView.clipsToBounds = false
        }
        mapView.register(UserLocationAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: annotationReuseId)
        mapView.delegate = self
        mapView.userTrackingMode = .follow
        tableView.dataSource = self
        tableView.delegate = self
        reloadLocations(coordinate: mapView.userLocation.coordinate)
        let isAuthorized = CLLocationManager.authorizationStatus() == .authorizedAlways
            || CLLocationManager.authorizationStatus() == .authorizedWhenInUse
        if isAuthorized {
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            break
        }
    }
    
    @IBAction func scrollToUserLocationAction(_ sender: Any) {
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)
    }
    
}

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        mapView.dequeueReusableAnnotationView(withIdentifier: annotationReuseId, for: annotation)
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        reloadLocations(coordinate: userLocation.coordinate)
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? LocationCell {
            cell.subtitleLabel.text = R.string.localizable.chat_location_accuracy(userLocationAccuracy)
        }
    }
    
}

extension LocationPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : locations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.location, for: indexPath)!
        if indexPath.section == 0 {
            cell.iconImageView.image = R.image.conversation.ic_location_user()
            cell.titleLabel.text = R.string.localizable.chat_location_send_current()
            cell.subtitleLabel.text = R.string.localizable.chat_location_accuracy(userLocationAccuracy)
        } else {
            let location = locations[indexPath.row]
            cell.render(location: location)
        }
        return cell
    }
    
}

extension LocationPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if let location = mapView.userLocation.location {
                send(coordinate: location.coordinate, name: nil, address: nil)
            } else {
                alert(R.string.localizable.chat_user_location_undetermined())
            }
        } else {
            let location = locations[indexPath.row]
            send(coordinate: location.coordinate, name: location.name, address: location.address)
        }
    }
    
}

extension LocationPickerViewController {
    
    private func reloadLocations(coordinate: CLLocationCoordinate2D) {
        NearbyLocationLoader.shared.search(coordinate: coordinate) { [weak self] (locations) in
            guard let self = self else {
                return
            }
            self.locations = locations
            self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        }
    }
    
    private func send(coordinate: CLLocationCoordinate2D, name: String?, address: String?) {
        let location = Location(latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                name: name,
                                address: address)
        do {
            try input.send(location: location)
            navigationController?.popViewController(animated: true)
        } catch {
            reporter.report(error: error)
            showAutoHiddenHud(style: .error, text: R.string.localizable.chat_send_location_failed())
        }
    }
    
}
