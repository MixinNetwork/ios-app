import Foundation
import CoreLocation
import MapKit

class NearbyLocationLoader {
    
    typealias Completion = ([Location]) -> Void
    
    enum Category: String, CaseIterable {
        
        case business
        case restaurant
        case fitness
        
        var image: UIImage? {
            switch self {
            case .business:
                return R.image.conversation.ic_location_category_business()
            case .restaurant:
                return R.image.conversation.ic_location_category_restaurant()
            case .fitness:
                return R.image.conversation.ic_location_category_fitness()
            }
        }
        
    }
    
    struct Location {
        
        let category: Category
        let coordinate: CLLocationCoordinate2D
        let name: String?
        let address: String?
        
        init(category: Category, item: MKMapItem) {
            self.category = category
            self.coordinate = item.placemark.coordinate
            self.name = item.name
            self.address = item.placemark.thoroughfare
        }
        
    }
    
    class LocalSearch: MKLocalSearch {
        
        let category: Category
        
        init(request: MKLocalSearch.Request, category: Category) {
            self.category = category
            super.init(request: request)
        }
        
    }
    
    static let shared = NearbyLocationLoader()
    
    private var coordinate: CLLocationCoordinate2D?
    private var isSearchingInProgress = false
    private var searches: [LocalSearch] = []
    private var fetchedLocations: [Category: [Location]] = [:]
    private var completions: [Completion] = []
    private var locations: [Location] = []
    
    func search(coordinate: CLLocationCoordinate2D, completion: @escaping Completion) {
        let hasCachedLocations: Bool
        if isSearchingInProgress {
            completions.append(completion)
            return
        } else if let previousCoordinate = self.coordinate {
            let previousLocation = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
            let thisLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            hasCachedLocations = previousLocation.distance(from: thisLocation) <= 500
        } else {
            hasCachedLocations = false
        }
        guard !hasCachedLocations else {
            completion(locations)
            return
        }
        
        self.coordinate = coordinate
        isSearchingInProgress = true
        searches.forEach {
            $0.cancel()
        }
        fetchedLocations = [:]
        completions.append(completion)
        
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: 1000,
                                        longitudinalMeters: 1000)
        let searches = Category.allCases.map { (category) -> LocalSearch in
            let request = MKLocalSearch.Request()
            request.region = region
            request.naturalLanguageQuery = category.rawValue
            return LocalSearch(request: request, category: category)
        }
        for search in searches {
            search.start { (response, error) in
                self.fetchedLocations[search.category] = response?.mapItems.map {
                    Location(category: search.category, item: $0)
                }
                self.searches.removeAll(where: { $0 == search })
                if self.searches.isEmpty {
                    let locations = self.fetchedLocations.values.reduce([], +)
                    for completion in self.completions {
                        completion(locations)
                    }
                    self.locations = locations
                }
            }
        }
        self.searches = searches
    }
    
}
