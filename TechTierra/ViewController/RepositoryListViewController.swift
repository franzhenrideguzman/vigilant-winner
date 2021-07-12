//
//  RepositoryListViewController.swift
//  TechTierra
//
//  Created by Franz Henri De Guzman on 7/9/21.
//

import UIKit
import SafariServices
import Alamofire
import AFNetworking
import GradientLoadingBar

class RepositoryListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    let searchBarPlaceholder = "Enter keywords"
    let navigationTitle = "Repos"

    let gradientLoadingBar = GradientLoadingBar(
        height: 5.0,
        isRelativeToSafeArea: true
    )

    @IBOutlet weak var tableView: UITableView!

    // Tool Tip
    @IBOutlet weak var toolTipView: UIView!
    @IBOutlet weak var toolTipLabel: UILabel!
    @IBOutlet weak var toolTipBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var toolTipTopConstraint: NSLayoutConstraint!

    var searchTerms = [String]()
    var usersSearch = [String]()
    var rawQueryParams = [[String: String]]()

    var searchBar = UISearchBar()
    var settingsViewController: SettingsViewController?

    // Infinite Scroll
    var currentPage = 1
    var isFetchingRepos = false
    var allReposFetched = false

    // All fetched repos
    var repoList = [Repository]()

    // Repos displayed in the table view.
    var displayRepoList = [Repository]()

    var refreshControl = UIRefreshControl()

    // MARK: - ViewController overrides

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        refreshRepos()
    }

    // MARK: - Setup Views

    private func setupViews() {
        title = navigationTitle
        setupTableView()
        setupToolTip()
        setupSearchBar()
        setupNavigationBar()
        setupSettings()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        tableView.backgroundColor = UIColor.clear

        // Make cell height dynamic
        tableView.estimatedRowHeight = 200.0
        tableView.rowHeight = UITableView.automaticDimension

        if let backgroundImage = UIImage(named: "blue-tiles") {
            view.backgroundColor = UIColor(patternImage: backgroundImage)
        }

        automaticallyAdjustsScrollViewInsets = false

        /*
            A UIRefreshControl sends a `valueChanged` event to signal
            when a refresh should occur.
        */
        refreshControl.addTarget(self, action: #selector(RepositoryListViewController.refreshRepos), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }

    private func setupToolTip() {
        toolTipLabel.text = nil
        toolTipLabel.backgroundColor = toolTipView.backgroundColor
        toolTipLabel.alpha = toolTipView.alpha
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = searchBarPlaceholder
        searchBar.autocapitalizationType = .none

        // Make search cursor visible (not white)
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = UIColor.black
    }

    private func setupSettings() {
        settingsViewController =
            UIStoryboard(
                name: "Main",
                bundle: nil
            ).instantiateViewController(
                withIdentifier: SettingsViewController.storyboardId
            ) as? SettingsViewController
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

        navigationItem.leftBarButtonItem =
            UIBarButtonItem(
                title: SettingsViewController.navigationTitle,
                style: .plain,
                target: self,
                action: #selector(RepositoryListViewController.displaySettings)
            )
        navigationItem.titleView = searchBar
    }

    // MARK: UI Target Actions
    @objc private func displaySettings() {
        if let settingsViewController = settingsViewController {
            settingsViewController.tableView?.reloadData()
            navigationController?.pushViewController(settingsViewController, animated: true)
        }
    }

    // MARK: - UITableView Delegate Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayRepoList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RepoTableViewCell") as! RepoTableViewCell
        cell.backgroundColor = UIColor.clear

        // Avoids index out of bounds errors when the displayed list is empty
        guard !displayRepoList.isEmpty else {
            return cell
        }

        populateRepoCell(cell: cell, repo: displayRepoList[indexPath.row])

        // Infinite scroll
        if(indexPath.row == repoList.count - 1 && indexPath.row != 0) {
            currentPage += 1
            getRepos()
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Open url in SFSafariViewController
        if let rawUrl = displayRepoList[indexPath.row].repoUrl, let url = URL(string: rawUrl) {
            let safariController = SFSafariViewController(url: url)
            present(safariController, animated: true, completion: nil)
        }
        else {
            let alert = UIAlertController(title: "Sorry, no URL exists for this repository", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                switch action.style {
                    case .default:
                    print("default")

                    case .cancel:
                    print("cancel")

                    case .destructive:
                    print("destructive")

                    @unknown default:
                        break
                }
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func populateRepoCell(cell: RepoTableViewCell, repo: Repository) {
        cell.repoNameLabel.text = repo.name
        cell.ownerNameLabel.text = repo.ownerLoginName

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        if let ownerAvatarUrl = repo.avatarUrl {
            if let imageUrl = URL(string: ownerAvatarUrl) {
                cell.ownerAvatarImage.setImageWith(imageUrl)
            }
        }

        cell.selectionStyle = .none

        if let ownerType = repo.ownerType {
            cell.ownerTypeLabel.text = ownerType
        }

        if let starCount = repo.starCount {
            cell.starCountLabel.text = numberFormatter.string(from: NSNumber(value: starCount))
        }

        if let watcherCount = repo.watcherCount {
            cell.watcherCountLabel.text = numberFormatter.string(from: NSNumber(value: watcherCount))
        }

        if let forkCount = repo.forkCount {
            cell.forkCountLabel.text = numberFormatter.string(from: NSNumber(value: forkCount))
        }

        if let language = repo.language {
            cell.languageLabel.text = language
        }
        else {
            // Collapses the label if there's no language
            cell.languageLabel.text = nil
        }

        if let repoDescription = repo.repoDescription {
            cell.descriptionLabel.text = repoDescription
        }
        else {
            cell.descriptionLabel.text = nil
        }
    }

    // MARK: - Search bar tool tip
    func hideToolTip() {
        UIView.animate(withDuration: 0.6) {
            self.toolTipLabel.text = nil
            self.toolTipTopConstraint.constant = 0
            self.toolTipBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }

    func showToolTip() {
        UIView.animate(withDuration: 0.6) {
            self.toolTipLabel.attributedText = self.toolTipAttributedText()
            self.toolTipTopConstraint.constant = 7
            self.toolTipBottomConstraint.constant = 10
            self.view.layoutIfNeeded()
        }
    }

    func toolTipAttributedText() -> NSAttributedString {
        let toolTipString = NSMutableAttributedString(string: "Search by ")// and/or user.\nE.g., \"swift user:techtierra\""

        let boldAttribute = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: toolTipLabel.font.pointSize)]
        let keywordString = NSMutableAttributedString(string: "keyword", attributes: boldAttribute)
        let userString = NSMutableAttributedString(string: "user", attributes: boldAttribute)

        let monospaceAttribute = [NSAttributedString.Key.font: UIFont(name: "Courier-Bold", size: toolTipLabel.font.pointSize)]
        let exampleString = NSMutableAttributedString(string: "swift user:techtierra", attributes: monospaceAttribute as [NSAttributedString.Key : Any])


        toolTipString.append(keywordString)
        toolTipString.append(NSMutableAttributedString(string: " and/or "))
        toolTipString.append(userString)
        toolTipString.append(NSMutableAttributedString(string: ".\nExample: "))
        toolTipString.append(exampleString)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.alignment = .center

        toolTipString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, toolTipString.length))

        return toolTipString
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard (searchText.count > 0) else {
            resetDisplayedRepos()
            return
        }

        do {
            displayRepoList = try repoList.filter() {
                (repo: Repository) throws -> Bool
                in
                let regex = try NSRegularExpression(pattern: "\(searchText)", options: [NSRegularExpression.Options.caseInsensitive])

                var numNameMatches = 0
                var numOwnerNameMatches = 0
                var numDescriptionMatches = 0

                if let name = repo.name {
                    numNameMatches = regex.numberOfMatches(in: name, options: [], range: NSRange(location: 0, length: name.count))
                }

                if let ownerName = repo.ownerLoginName {
                    numOwnerNameMatches = regex.numberOfMatches(in: ownerName, options: [], range: NSRange(location: 0, length: ownerName.count))
                }

                if let repoDescription = repo.repoDescription {
                    numDescriptionMatches = regex.numberOfMatches(in: repoDescription, options: [], range: NSRange(location: 0, length: repoDescription.count))
                }

                if(numNameMatches + numOwnerNameMatches + numDescriptionMatches > 0) {
                    return true
                }
                else {
                    return false
                }
            }
        }
        catch {
            // NSRegularExpression error
            print("\(error)")
        }
        tableView.reloadData()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        tableView.setContentOffset(CGPoint.zero, animated: true)
        searchBar.showsCancelButton = true

        showToolTip()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        hideToolTip()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.showsCancelButton = false

        if searchTerms.isEmpty && usersSearch.isEmpty {
            resetDisplayedRepos()
        }
        else {
            refreshReposAfterSearch()
        }

        searchBar.endEditing(true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        clearSearches()

        if let searchBarText = searchBar.text {
            if searchBarText.count > 0 {
                // Categorize user searchs and keyword searches
                for term in searchBarText.components(separatedBy: " ") {
                    do {
                        // search for the `user:<username>` syntax
                        let regex = try NSRegularExpression(pattern: "^user:([^\\s]+)$", options: [NSRegularExpression.Options.caseInsensitive])
                        let results = regex.matches(in: term, options: [], range: NSRange(location: 0, length: term.count))

                        if results.isEmpty {
                            searchTerms.append(term)
                        }
                        else {
                            let termString = term as NSString

                            for result in results {
                                // add the first capturing group, which is the username
                                let userName = termString.substring(with: result.range(at: 1))
                                usersSearch.append(userName)
                            }
                        }
                    }
                    catch {
                        print("NSRegularExpression error: \(error)")
                    }
                }

                refreshRepos()
            }
            else {
                refreshReposAfterSearch()
            }
        }
        searchBar.endEditing(true)
    }

    // If a search was performed and then cleared,
    // refetch repos using user preferences.
    func refreshReposAfterSearch() {
        if !searchTerms.isEmpty || !usersSearch.isEmpty {
            clearSearches()
            refreshRepos()
        }
    }

    private func clearSearches() {
        searchTerms.removeAll()
        usersSearch.removeAll()
    }

    // MARK: - User filter preferences

    private func loadPreferencesIntoQueryMap() {
        rawQueryParams.removeAll()

        let preferences = UserDefaults.standard

        if let minStars = preferences.value(forKey: SettingsViewController.minStarsKey) as? Int {
            rawQueryParams.append(createQueryParamMapEntry(key: GithubClient.stars, value: String(minStars)))
        }

        if let searchByLanguageEnabled = preferences.value(forKey: SettingsViewController.searchByLanguageEnabledKey) as? Bool {
            if(searchByLanguageEnabled) {
                // Only add language filters if the language filter toggle is enabled.
                if let languages = preferences.value(forKey: SettingsViewController.selectedLanguagesKey) as? [String] {
                    for language in languages {
                        rawQueryParams.append(
                            createQueryParamMapEntry(key: GithubClient.language, value: language)
                        )
                    }
                }
            }
        }

    }

    private func createQueryParamMapEntry(key: String, value: String) -> [String: String] {
        return
            [
                "\(GithubClient.queryParamKey)": "\(key)",
                "\(GithubClient.queryParamValue)": "\(value)",
            ]
    }

    // MARK: - Search Repos

    @objc private func refreshRepos() {
        // Clear repos
        repoList.removeAll()
        displayRepoList = repoList

        // Reset current page
        currentPage = 1
        allReposFetched = false

        // Fetch repos
        getRepos()
    }

    // Resets the display repo list to show all
    // the fetched repos in the table view.
    private func resetDisplayedRepos() {
        displayRepoList = repoList
        tableView.reloadData()
    }

    private func getRepos() {
        // Don't fetch repos if currently fetching or
        // if all repos have already been fetched.
        guard !isFetchingRepos && !allReposFetched else {
            return
        }

        loadPreferencesIntoQueryMap()
        loadUsersSearchIntoQueryMap()

        print(searchTerms)
        print(rawQueryParams)
        searchRepos(searchTerms: searchTerms, rawQueryParams: rawQueryParams)
    }

    private func loadUsersSearchIntoQueryMap() {
        if !usersSearch.isEmpty {
            for userName in usersSearch {
                rawQueryParams.append(createQueryParamMapEntry(key: "user", value: userName))
            }
        }
    }

    private func searchRepos(searchTerms: [String]?, rawQueryParams: [[String: String]]?) {
        var logMessage = "Fetching repos with the following params:\n"

        if let rawQueryParams = rawQueryParams {
            for param in rawQueryParams {
                guard let key = param[GithubClient.queryParamKey],
                       let value = param[GithubClient.queryParamValue] else {
                    continue
                }
                logMessage.append("\t\(key): \(value)\n")
            }
        }
        else {
            logMessage.append("\tNo params specified")
        }

        print(logMessage)

        if let url = GithubClient.createSearchReposUrl(searchTerms: searchTerms, rawQueryParams: rawQueryParams, sort: nil, page: currentPage) {
            GithubClient.logRequest(url: url)

            isFetchingRepos = true
            gradientLoadingBar.fadeIn()

            let request = AF.request(url)

            request.responseJSON() {
                response in
                switch response.result {
                case .success:
                    // response.result.value is a [String: Any] object
                    if let itemsResponse = (response.value as? [String: Any])?["items"] as? [[String: Any]] {
                        if(itemsResponse.isEmpty) {
                            self.allReposFetched = true
                        }

                        for item in itemsResponse {
                            let repo = Repository(responseMap: item)
                            self.repoList.append(repo)
                        }
                    }

                    self.isFetchingRepos = false
                    self.gradientLoadingBar.fadeOut()

                    self.resetDisplayedRepos()

                    if self.refreshControl.isRefreshing {
                        self.refreshControl.endRefreshing()
                    }

                case .failure:
                    let alertController = UIAlertController(title: "Network error", message: "Could not fetch repositorie", preferredStyle: UIAlertController.Style.alert)

                    alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))

                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}

