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
        
        self.urlSchemeSwitchCell.titeLabel?.text = NSLocalizedString("Using URL Scheme", comment: "通过URL Scheme 自动打开应用")
        if let urlSchemeSwitchView = self.urlSchemeSwitchCell.accessoryView {
            let urlSchemeSwitch = urlSchemeSwitchView as! UISwitch
            urlSchemeSwitch.isOn = groupDefaults.bool(forKey: VideoMarksConstants.kIsUsingURLScheme)
        }
        
        
    }
    
    @IBAction func switchURLScheme(_ sender: UISwitch) {
        let groupDefaults = UserDefaults.init(suiteName: VideoMarksConstants.appGroupID)!
        groupDefaults.set(sender.isOn, forKey: VideoMarksConstants.kIsUsingURLScheme)
        groupDefaults.synchronize()
        UserDefaults.standard.set(sender.isOn, forKey: VideoMarksConstants.kIsUsingURLScheme)
        UserDefaults.standard.synchronize()
    }
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}
