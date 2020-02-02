import UIKit

protocol SelectCountryViewControllerDelegate: class {
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country)
}

class SelectCountryViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    
    typealias Section = [Country]
    
    enum SectionIndex {
        static let currentSelected = 0
        static let currentLocation = 1
    }
    
    enum ReuseId {
        static let cell = "country_cell"
        static let header = "country_header"
    }
    
    var selectedCountry: Country!
    weak var delegate: SelectCountryViewControllerDelegate?

    private let sectionHeaderHeight: CGFloat = 38
    private var sections = [Section]()
    private var sectionIndexTitles = [String]()
    private var filteredCountries = [Country]()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let countries = CountryCodeLibrary.shared.countries
        let selector = #selector(getter: Country.localizedName)
        (sectionIndexTitles, sections) = UILocalizedIndexedCollation.current().catalogue(countries, usingSelector: selector)
        tableView.register(GeneralTableViewHeader.self, forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        searchBoxView.textField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
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
                .filter{ $0.localizedName.uppercased().hasPrefix(searchText) }
        }
        tableView.reloadData()
        DispatchQueue.main.async {
            if searchText.isEmpty {
                self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }
    
    static func instance(selectedCountry: Country) -> SelectCountryViewController {
        let vc = R.storyboard.login.selectCountry()!
        vc.selectedCountry = selectedCountry
        return vc
    }
    
    private var shouldShowFilteredResults: Bool {
        let searchTextFieldIsEmpty = (searchBoxView.textField.text ?? "").isEmpty
        return searchBoxView.textField.isFirstResponder && !searchTextFieldIsEmpty
    }
    
}

extension SelectCountryViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if shouldShowFilteredResults {
            return filteredCountries.count
        } else {
            if section < 2 {
                return 1
            } else {
                return sections[section - 2].count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell)! as! CountryCell
        let country: Country
        if shouldShowFilteredResults {
            country = filteredCountries[indexPath.row]
        } else {
            if indexPath.section == SectionIndex.currentSelected {
                country = selectedCountry
            } else if indexPath.section == SectionIndex.currentLocation {
                country = CountryCodeLibrary.shared.deviceCountry
            } else {
                country = sections[indexPath.section - 2][indexPath.row]
            }
        }
        cell.flagImageView.image = UIImage(named: country.isoRegionCode.lowercased())
        cell.nameLabel.text = country.localizedName
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return shouldShowFilteredResults ? 1 : sections.count + 2
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return shouldShowFilteredResults ? nil : sectionIndexTitles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index + 2
    }

}

extension SelectCountryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !shouldShowFilteredResults else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header)! as! GeneralTableViewHeader
        if section == SectionIndex.currentSelected {
            header.label.text = Localized.HEADER_TITLE_CURRENT_SELECTED
        } else if section == SectionIndex.currentLocation {
            header.label.text = Localized.HEADER_TITLE_CURRENT_LOCATION
        } else {
            header.label.text = sectionIndexTitles[section - 2]
        }
        header.labelTopConstraint.constant = 10
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return shouldShowFilteredResults ? .leastNormalMagnitude : sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if shouldShowFilteredResults {
            delegate?.selectCountryViewController(self, didSelectCountry: filteredCountries[indexPath.row])
        } else {
            if indexPath.section == 0 {
                delegate?.selectCountryViewController(self, didSelectCountry: selectedCountry)
            } else if indexPath.section == 1 {
                delegate?.selectCountryViewController(self, didSelectCountry: CountryCodeLibrary.shared.deviceCountry)
            } else {
                delegate?.selectCountryViewController(self, didSelectCountry: sections[indexPath.section - 2][indexPath.row])
            }
        }
    }

}

extension SelectCountryViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.text = nil
        textField.resignFirstResponder()
        filteredCountries = []
        tableView.reloadData()
        return true
    }

}
