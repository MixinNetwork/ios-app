import UIKit

final class MemoViewController: PopupSelectorViewController {
    
    private struct MemoViewModel {
        let title: String
        let content: String
    }
    
    private let viewModels: [MemoViewModel]
    
    init(rawMemo: String, utf8DecodedMemo: String) {
        self.viewModels = [
            MemoViewModel(title: "UTF-8", content: utf8DecodedMemo),
            MemoViewModel(title: "Hex", content: rawMemo),
        ]
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewBottomInset()
        tableView.register(R.nib.memoCell)
        tableView.dataSource = self
        titleView.titleLabel.text = R.string.localizable.memo()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewBottomInset()
    }
    
    private func updateTableViewBottomInset() {
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 22 + view.safeAreaInsets.bottom, right: 0)
    }
    
}

extension MemoViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.memo, for: indexPath)!
        let viewModel = viewModels[indexPath.row]
        cell.titleLabel.text = viewModel.title
        cell.contentLabel.text = viewModel.content
        return cell
    }
    
}
