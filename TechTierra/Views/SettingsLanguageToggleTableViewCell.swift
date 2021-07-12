//
//  SettingsLanguageToggleTableViewCell.swift
//  TechTierra
//
//  Created by Franz Henri De Guzman on 7/11/21.
//


import UIKit

class SettingsLanguageToggleTableViewCell: UITableViewCell {

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var languageSwitch: UISwitch!

    let descriptionText = "Filter by language"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        descriptionLabel.text = descriptionText
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
