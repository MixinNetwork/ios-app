import UIKit

class DesktopViewController: UIViewController {
    
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet var tableView: UITableView!
    
    private let cellReuseId = "cell"
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "desktop") as! DesktopViewController
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_DESKTOP)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        updateStatusImageView()
    }
    
    private func updateStatusImageView() {
        statusImageView.image = ProvisionManager.isDesktopLoggedIn
            ? UIImage(named: "ic_desktop_on")
            : UIImage(named: "ic_desktop_off")
    }
    
}

extension DesktopViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId)!
        if ProvisionManager.isDesktopLoggedIn {
            cell.textLabel?.text = Localized.SETTING_DESKTOP_LOG_OUT
            cell.textLabel?.textColor = .systemTint
        } else {
            cell.textLabel?.text = Localized.SCAN_QR_CODE
            cell.textLabel?.textColor = .black
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?  {
        return nil
    }
    
}

extension DesktopViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if ProvisionManager.isDesktopLoggedIn {
            
        } else {
            let vc = CameraViewController.instance()
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

extension DesktopViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        if let url = MixinURL(string: string), case let .device(uuid, publicKey) = url {
            ProvisionManager.updateProvision(uuid: uuid, base64EncodedPublicKey: publicKey, completion: { [weak self] success in
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                    self?.updateStatusImageView()
                }
            })
            navigationController?.popViewController(animated: true)
        }
        return false
    }
    
}
