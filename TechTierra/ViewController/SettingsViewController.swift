//
//  SettingsViewController.swift
//  TechTierra
//
//  Created by Franz Henri De Guzman on 7/11/21.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SettingsMinStarCountTableViewCellDelegate {
    public static let storyboardId = "settingsViewController"
    public static let navigationTitle = "Filters"

    @IBOutlet weak var tableView: UITableView!

    var saveButtonItem: UIBarButtonItem?
    var cancelButtonItem: UIBarButtonItem?

    let saveButtonTitle = "Save"
    let cancelButtonTitle = "Cancel"

    // Section header text
    let ratingSectionTitle = "Rating"
    let languageSectionTitle = "Language"

    // Lazy loaded variable allows `self` to be instantiated
    // before assignment.
    lazy var sectionHeaderTextList: [String] =
        [self.ratingSectionTitle, self.languageSectionTitle]

    let numLanguageSettingRows = 1

    // Languages
    let defaultLanguages: Set<String> = [
        "Swift", "Java", "Ruby", "Go", "Python", "C", "C++"
    ]

    // Populates table view with languages.  The language enabled switch toggles this
    // value between all languages and an empty array.
    var displayedLanguages = [String]()

    // User preferences
    static let searchByLanguageEnabledKey = "searchByLanguage"
    static let selectedLanguagesKey = "selectedLanguages"
    static let minStarsKey = "minStars"

    var selectedLanguages: Set<String>?
    var searchByLanguageEnabled: Bool?
    var minStars: Int?

    // MARK: UIViewController Overrides

    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = SettingsViewController.navigationTitle

        loadPreferences()
        setupViews()
    }

    // MARK: - User preferences

    private func loadPreferences() {
        let userDefaults = UserDefaults.standard

        minStars = userDefaults.value(forKey: SettingsViewController.minStarsKey) as? Int ?? 0

        // Sets are not eligible for storage in UserDefaults
        let selectedLanguagesArray =
            userDefaults.value(forKey: SettingsViewController.selectedLanguagesKey) as? [String] ?? [String]()
        selectedLanguages = Set(selectedLanguagesArray)

        searchByLanguageEnabled = userDefaults.value(forKey: SettingsViewController.searchByLanguageEnabledKey) as? Bool ?? false
    }

    private func savePreferences() {
        let userDefaults = UserDefaults.standard

        userDefaults.set(minStars, forKey: SettingsViewController.minStarsKey)
        userDefaults.set(Array(selectedLanguages!), forKey: SettingsViewController.selectedLanguagesKey)
        userDefaults.set(searchByLanguageEnabled, forKey: SettingsViewController.searchByLanguageEnabledKey)

        print("\nSaving User Defaults.")
        print("\tminStars: \(minStars!)")
        print("\tselectedLanguages: \(selectedLanguages!)")
        print("\tsearchByLanguageEnabled: \(searchByLanguageEnabled!)\n")
    }

    // MARK: Setup Views

    private func setupViews() {
        initializeViewData()
        setupTableView()
        setupNavigationBar()
    }

    private func initializeViewData() {
        // Populate languages to display if filter by language is enabled.
        if let searchByLanguageEnabled = searchByLanguageEnabled {
            if(searchByLanguageEnabled) {
                displayedLanguages = allLanguagesArray()
            }
        }
    }

    private func setupNavigationBar() {
        saveButtonItem = UIBarButtonItem(
            title: saveButtonTitle,
            style: .plain,
            target: self,
            action: #selector(SettingsViewController.saveSettings)
        )

        cancelButtonItem = UIBarButtonItem(
            title: cancelButtonTitle,
            style: .plain,
            target: self,
            action: #selector(SettingsViewController.cancelSettings)
        )

        navigationItem.leftBarButtonItem = saveButtonItem
        navigationItem.rightBarButtonItem = cancelButtonItem
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self

        // Remove padding around table view
        automaticallyAdjustsScrollViewInsets = false
    }

    // MARK: - UITableViewDelegate Protocol


    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionHeaderTextList.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionHeaderTextList[section]
    }

    /*
        Required protocol method.
    */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Min stars rating contains a single row
        var numRows = 1

        if(sectionHeaderTextList[section] == languageSectionTitle) {
            numRows = displayedLanguages.count + 1
        }

        return numRows
    }

    /*
        Required protocol method.
     */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Min star rating
        if(sectionHeaderTextList[indexPath.section] == ratingSectionTitle) {
            return minStarTableViewCell()
        }
        // Languages filter
        else {
            // First row is the language toggle
            if(indexPath.row == 0) {
                return languageToggleCell()
            }
            else {
                return languageCell(indexPath: indexPath)
            }
        }
    }

    private func minStarTableViewCell() -> SettingsMinStarCountTableViewCell {
        let minStarsCell =
            tableView.dequeueReusableCell(
                withIdentifier: "SettingsMinStarCountTableViewCell"
            ) as! SettingsMinStarCountTableViewCell

        // Allow updating of minStars from the cell
        minStarsCell.delegate = self

        minStarsCell.setMinStars(minStars: minStars!)

        return minStarsCell
    }

    private func languageToggleCell() -> SettingsLanguageToggleTableViewCell {
        // Filter by language cell.
        let languageToggleCell = tableView.dequeueReusableCell(withIdentifier: "SettingsLanguageToggleTableViewCell") as! SettingsLanguageToggleTableViewCell

        // Trigger showing or hiding of languages and setting the preference value.
        languageToggleCell.languageSwitch.addTarget(self, action: #selector(SettingsViewController.onLanguageToggle(sender:)), for: UIControl.Event.touchUpInside)

        // Set the toggle to the correct value based on the user preference value
        languageToggleCell.languageSwitch.setOn(searchByLanguageEnabled!, animated: false)

        return languageToggleCell
    }

    private func languageCell(indexPath: IndexPath) -> SettingsLanguageTableViewCell {
        // Specific language cells.
        let languageCell =
            tableView.dequeueReusableCell(
                withIdentifier: "SettingsLanguageTableViewCell"
                ) as! SettingsLanguageTableViewCell

        // Set label text
        let language = displayedLanguages[indexPath.row - 1] // First row is the toggle
        languageCell.languageLabel.text = language

        // Use user preferences to check/uncheck language
        if let selectedLanguages = selectedLanguages {
            if(selectedLanguages.contains(language)) {
                languageCell.accessoryType = UITableViewCell.AccessoryType.checkmark
            }
            else {
                languageCell.accessoryType = UITableViewCell.AccessoryType.none
            }
        }

        // Alternate row coloring
        if indexPath.row % 2 == 1 {
            // Light gray
            languageCell.backgroundColor =
                UIColor(
                    red: 0.95,
                    green: 0.95,
                    blue: 0.95,
                    alpha: 1.0
            )
        }

        return languageCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Check or un-check languages
        if let cell = tableView.cellForRow(at: indexPath) as? SettingsLanguageTableViewCell {
            let language = cell.languageLabel.text

            if (cell.accessoryType == UITableViewCell.AccessoryType.checkmark) {
                cell.accessoryType = UITableViewCell.AccessoryType.none
                _ = selectedLanguages?.remove(language!)
            }
            else {
                cell.accessoryType = UITableViewCell.AccessoryType.checkmark
                selectedLanguages?.insert(language!)
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - IB Target Actions

    @objc private func saveSettings() {
        print("\nSave button tapped\n")
        savePreferences()
        dismiss()
    }

    @objc private func cancelSettings() {
        print("\nCancel button tapped\n")
        
        let alert = UIAlertController(title: "Do you want to discard changes?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style {
                case .default:
                print("default")
                if let searchByLanguageEnabled = self.searchByLanguageEnabled {
                        self.showOrHideLanguages(showLanguages: searchByLanguageEnabled)
                }

                self.dismiss()

                case .cancel:
                print("cancel")

                case .destructive:
                print("destructive")

                @unknown default:
                    break
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
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

    @objc private func onLanguageToggle(sender: UISwitch) {
        searchByLanguageEnabled = sender.isOn
        showOrHideLanguages(showLanguages: searchByLanguageEnabled!)
    }

    private func showOrHideLanguages(showLanguages: Bool) {
        // Create IndexPath objects for each row in the languages section.
        var indexPaths = [IndexPath]()

        guard let languagesSectionIndex = self.sectionHeaderTextList.index(of: self.languageSectionTitle) else {
            print("Error: No language section")
            return
        }

        // Exclude the first row, which is the language filter toggle.
        for i in 1...self.allLanguagesArray().count {
            indexPaths.append(IndexPath(row: i, section: languagesSectionIndex))
        }

        if showLanguages {
            // Show languages
            self.displayedLanguages = self.allLanguagesArray()

            if self.tableView.numberOfRows(inSection: languagesSectionIndex) == self.numLanguageSettingRows {
                self.tableView.insertRows(at: indexPaths, with: UITableView.RowAnimation.bottom)
            }
        }
            // Only hide languages if they're visible.
        else if(self.tableView.numberOfRows(inSection: languagesSectionIndex) > self.numLanguageSettingRows){
            self.displayedLanguages.removeAll()

            // Remove language rows from table with animation
            self.tableView.deleteRows(at: indexPaths, with: UITableView.RowAnimation.bottom)
        }
    }

    // MARK: - Convenience methods

    private func allLanguagesArray() -> [String] {
        return
            Array(
                defaultLanguages
            ).sorted() { (s1, s2) in s1 < s2 }
    }

    // MARK: - SettingsMinStartCountTableViewCellDelegate

    // When the min start count slider changes, update the min star count.
    func onMinStarCountChange(sender: SettingsMinStarCountTableViewCell) {
        minStars = sender.desiredMinStars
    }

    // MARK: - Navigation

    private func dismiss() {
        // Need to assign return value to avoid warning
        // http://stackoverflow.com/questions/37843049/xcode-8-swift-3-expression-of-type-uiviewcontroller-is-unused-warning
        _ = navigationController?.popViewController(animated: true)
    }
}
