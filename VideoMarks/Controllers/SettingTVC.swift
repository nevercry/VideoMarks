//
//  SettingTVC.swift
//  VideoMarks
//
//  Created by shengfu yang on 03/02/2017.
//  Copyright © 2017 nevercry. All rights reserved.
//

import UIKit

class SettingTVC: UITableViewController {

    @IBOutlet weak var urlSchemeSwitchCell: SwitchSettingCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configSettingUI()
    }

    func configSettingUI() {
        self.title = NSLocalizedString("Setting", comment: "设置")
        let groupDefaults = UserDefaults.init(suiteName: VideoMarksConstants.appGroupID)!
        
        self.urlSchemeSwitchCell.titeLabel?.text = NSLocalizedString("Custom URL Scheme", comment: "自定义 URL Scheme")
        
        if let urlSchemeString = groupDefaults.string(forKey: VideoMarksConstants.kCustomURLScheme) {
            self.urlSchemeSwitchCell.urlSchemeTextFeild?.text = urlSchemeString
        } else {
            self.urlSchemeSwitchCell.urlSchemeTextFeild?.text = ""
        }
    }
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        self.tableView.endEditing(true)
        if let urlSchemeString = self.urlSchemeSwitchCell.urlSchemeTextFeild?.text {
            if validateURLSchemeString(urlString: urlSchemeString) == true {
                let groupDefaults = UserDefaults.init(suiteName: VideoMarksConstants.appGroupID)!
                groupDefaults.set(urlSchemeString, forKey: VideoMarksConstants.kCustomURLScheme)
                groupDefaults.synchronize()
            }
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func validateURLSchemeString(urlString: String) -> Bool {
        do {
            let urlSchemeRegex = try NSRegularExpression(pattern: "\\b^[a-zA-Z0-9]+://", options: .caseInsensitive)
            let numOfMatch = urlSchemeRegex.numberOfMatches(in: urlString, options: .reportCompletion, range: NSMakeRange(0, urlString.characters.count))
            
            print("number of match is \(numOfMatch)")
            
            if numOfMatch > 0 {
                print("valide url scheme")
                return true
            }
        } catch {
            fatalError("regex error is \(error)")
        }
        
        print("url scheme invalid")
        
        return false
    }
}
