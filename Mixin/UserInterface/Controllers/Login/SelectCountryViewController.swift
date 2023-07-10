import UIKit

protocol SelectCountryViewControllerDelegate: AnyObject {
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country)
}

class SelectCountryViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    
    typealias Section = [Country]
    
    enum FixedSection: Int, CaseIterable {
        case currentSelected = 0
        case currentLocation = 1
        case anonymousNumber = 2
    }
    
    enum ReuseId {
        static let cell = "country_cell"
        static let header = "country_header"
    }
    
    var library: CountryLibrary!
    var selectedCountry: Country!
    
    weak var delegate: SelectCountryViewControllerDelegate?

    private let sectionHeaderHeight: CGFloat = 38
    
    private var sections = [Section]()
    private var sectionIndexTitles = [String]()
    private var filteredCountries = [Country]()
    
    private var isSearching: Bool {
        !searchBoxView.textField.text.isNilOrEmpty
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let selector = #selector(getter: Country.localizedName)
        (sectionIndexTitles, sections) = UILocalizedIndexedCollation.current().catalog(library.countries, usingSelector: selector)
        tableView.register(GeneralTableViewHeader.self, forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        searchBoxView.textField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        searchBoxView.textField.delegate = self
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func searchAction(_ sender: Any) {
        let searchText = (searchBoxView.textField.text ?? "").uppercased()
        if searchText.isEmpty {
            filteredCountries = []
        } else {
            filteredCountries = sections
                .flatMap{ $0 }
                .filter{ $0.localizedName.uppercased().hasPrefix(searchText) || $0.callingCode.hasPrefix(searchText) }
        }
        tableView.reloadData()
        DispatchQueue.main.async {
            if searchText.isEmpty {
                self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }
    
    static func instance(library: CountryLibrary, selectedCountry: Country) -> SelectCountryViewController {
        let vc = R.storyboard.login.selectCountry()!
        vc.library = library
        vc.selectedCountry = selectedCountry
        return vc
    }
    
    private func country(at indexPath: IndexPath) -> Country {
        if isSearching {
            return filteredCountries[indexPath.row]
        } else {
            switch indexPath.section {
            case FixedSection.currentSelected.rawValue:
                return selectedCountry
            case FixedSection.currentLocation.rawValue:
                return library.deviceCountry
            case FixedSection.anonymousNumber.rawValue:
                return .anonymous
            default:
                let section = sections[indexPath.section - FixedSection.allCases.count]
                return section[indexPath.row]
            }
        }
    }
    
}

extension SelectCountryViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return filteredCountries.count
        } else {
            if section < FixedSection.allCases.count {
                return 1
            } else {
                return sections[section - FixedSection.allCases.count].count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell)! as! CountryCell
        let country = country(at: indexPath)
        cell.flagImageView.image = UIImage(named: country.isoRegionCode.lowercased())
        cell.nameLabel.text = country.localizedName
        cell.codeLabel.text = "+" + country.callingCode
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : FixedSection.allCases.count + sections.count
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return isSearching ? nil : sectionIndexTitles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index + FixedSection.allCases.count
    }

}

extension SelectCountryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearching else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header)! as! GeneralTableViewHeader
        switch section {
        case FixedSection.currentSelected.rawValue:
            header.label.text = R.string.localizable.current_selected()
        case FixedSection.currentLocation.rawValue:
            header.label.text = R.string.localizable.current_location()
        case FixedSection.anonymousNumber.rawValue:
            header.label.text = R.string.localizable.anonymous_number()
        default:
            header.label.text = sectionIndexTitles[section - FixedSection.allCases.count]
        }
        header.labelTopConstraint.constant = 10
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearching ? .leastNormalMagnitude : sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let country = country(at: indexPath)
        delegate?.selectCountryViewController(self, didSelectCountry: country)
    }

}

extension SelectCountryViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
