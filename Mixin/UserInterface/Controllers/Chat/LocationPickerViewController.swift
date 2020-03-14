import UIKit
import CoreLocation
import MapKit
import MixinServices
import Alamofire

class LocationPickerViewController: LocationViewController {
    
    override var tableViewMaskHeight: CGFloat {
        willSet {
            mapViewCenterCoordinateBeforeTableViewMaskChanges = mapView.centerCoordinate
        }
        didSet {
            pinImageViewIfLoaded?.center = pinImageViewCenter
            scrollToUserLocationButtonBottomConstraint.constant = tableViewMaskHeight + 20
            if userDidDropThePin {
                var point = mapView.convert(mapView.centerCoordinate, toPointTo: mapView)
                point.y += (tableViewMaskHeight - oldValue) / 2
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                mapView.setCenter(coordinate, animated: false)
            }
        }
    }
    
    private let scrollToUserLocationButton = UIButton()
    private let pinImage = R.image.conversation.ic_annotation_pin()!
    private let nearbyLocationSearchingIndicator = ActivityIndicatorView()
    
    private lazy var geocoder = CLGeocoder()
    private lazy var pinImageView = UIImageView(image: pinImage)
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()
    
    private weak var pinImageViewIfLoaded: UIImageView?
    
    private var input: ConversationInputViewController!
    private var scrollToUserLocationButtonBottomConstraint: NSLayoutConstraint!
    private var mapViewCenterCoordinateBeforeTableViewMaskChanges: CLLocationCoordinate2D!
    private var userDidDropThePin = false
    private var userPinnedLocationAddress: String?
    private var nearbyLocationsRequest: Request?
    private var nearbyLocationsSearchCoordinate: CLLocationCoordinate2D?
    private var nearbyLocations: [FoursquareLocation] = []
    
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
    
    private var pinCenter: CGPoint {
        CGPoint(x: view.bounds.midX, y: (view.bounds.height - tableViewMaskHeight) / 2)
    }
    
    private var pinImageViewCenter: CGPoint {
        let pinCenter = self.pinCenter
        return CGPoint(x: pinCenter.x, y: pinCenter.y - pinImage.size.height / 2)
    }
    
    convenience init(input: ConversationInputViewController) {
        self.init(nib: R.nib.locationView)
        self.input = input
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        let userDragRecognizer = UIPanGestureRecognizer(target: self, action: #selector(userDragMapAction(_:)))
        mapView.addGestureRecognizer(userDragRecognizer)
        userDragRecognizer.delegate = self
        
        tableView.dataSource = self
        tableView.delegate = self
        
        view.addSubview(scrollToUserLocationButton)
        scrollToUserLocationButton.setImage(R.image.conversation.ic_scroll_to_user_location(), for: .normal)
        scrollToUserLocationButton.addTarget(self, action: #selector(scrollToUserLocationAction(_:)), for: .touchUpInside)
        scrollToUserLocationButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(44)
            make.trailing.equalToSuperview().offset(-12)
        }
        scrollToUserLocationButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: scrollToUserLocationButton.bottomAnchor)
        scrollToUserLocationButtonBottomConstraint.isActive = true
        if let imageView = scrollToUserLocationButton.imageView {
            imageView.contentMode = .center
            imageView.clipsToBounds = false
        }
        
        nearbyLocationSearchingIndicator.tintColor = .theme
        nearbyLocationSearchingIndicator.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 240)
        
        if mapView.userLocation.coordinate.latitude != 0 || mapView.userLocation.coordinate.longitude != 0 {
            reloadNearbyLocations(coordinate: mapView.userLocation.coordinate)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            if let location = mapView.userLocation.location {
                send(coordinate: location.coordinate, name: nil, address: nil)
            } else {
                alert(R.string.localizable.chat_user_location_undetermined())
            }
        } else {
            let location = nearbyLocations[indexPath.row]
            send(coordinate: location.coordinate, name: location.name, address: location.address)
        }
    }
    
    @objc private func scrollToUserLocationAction(_ sender: Any) {
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)
    }
    
    @objc private func userDragMapAction(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        userDidDropThePin = true
        mapView.userTrackingMode = .none
        if pinImageView.superview == nil {
            pinImageView.center = pinImageViewCenter
            view.addSubview(pinImageView)
            pinImageViewIfLoaded = pinImageView
        }
    }
    
}

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard userDidDropThePin && !tableView.isTracking && !tableView.isDecelerating else {
            return
        }
        geocoder.cancelGeocode()
        userPinnedLocationAddress = nil
        reloadFirstCell()
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard userDidDropThePin && !tableView.isTracking && !tableView.isDecelerating else {
            return
        }
        let coordinate = mapView.convert(pinCenter, toCoordinateFrom: view)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else {
                return
            }
            if let address = placemarks?.first?.postalAddress {
                self.userPinnedLocationAddress = address.street
            } else {
                self.userPinnedLocationAddress = ""
            }
            self.reloadFirstCell()
        }
        reloadNearbyLocations(coordinate: coordinate)
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !userDidDropThePin {
            reloadNearbyLocations(coordinate: userLocation.coordinate)
            reloadFirstCell()
        }
    }
    
}

extension LocationPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : nearbyLocations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.location, for: indexPath)!
        if indexPath.section == 0 {
            if userDidDropThePin {
                cell.renderAsUserPickedLocation(address: userPinnedLocationAddress)
            } else {
                cell.renderAsUserLocation(accuracy: userLocationAccuracy)
            }
        } else {
            let location = nearbyLocations[indexPath.row]
            cell.render(location: location)
        }
        return cell
    }
    
}

extension LocationPickerViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
}

extension LocationPickerViewController {
    
    private func reloadNearbyLocations(coordinate: CLLocationCoordinate2D) {
        let willSearchCoordinateAtLeast100MetersAway = nearbyLocationsSearchCoordinate == nil
            || coordinate.distance(from: nearbyLocationsSearchCoordinate!) >= 100
        guard willSearchCoordinateAtLeast100MetersAway else {
            return
        }
        nearbyLocations = []
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        if tableView.tableFooterView == nil {
            nearbyLocationSearchingIndicator.startAnimating()
            tableView.tableFooterView = nearbyLocationSearchingIndicator
        }
        nearbyLocationsRequest?.cancel()
        nearbyLocationsRequest = FoursquareAPI.search(coordinate: coordinate) { [weak self] (result) in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let locations):
                self.nearbyLocationSearchingIndicator.stopAnimating()
                self.tableView.tableFooterView = nil
                self.nearbyLocations = locations
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                self.nearbyLocationsSearchCoordinate = coordinate
            case .failure:
                break
            }
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
    
    private func reloadFirstCell() {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
}
