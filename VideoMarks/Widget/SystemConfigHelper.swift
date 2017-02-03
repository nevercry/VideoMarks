//
//  SystemConfigHelper.swift
//  VideoMarks
//
//  Created by shengfu yang on 03/02/2017.
//  Copyright © 2017 nevercry. All rights reserved.
//

import UIKit

class SystemConfigHelper {
    static let shareInstance = SystemConfigHelper()
    
    func readingPreference() {
        // 获取Settings.bundle 路径
        if let settingsBundle = Bundle.main.path(forResource: "Settings", ofType: "bundle") {
            let settings = NSDictionary(contentsOfFile: (settingsBundle as NSString).appendingPathComponent("Root.plist"))
            let preferences = settings?.object(forKey: "PreferenceSpecifiers") as! [NSDictionary]
            var defaultsToRegister:[String:Any] = Dictionary(minimumCapacity: preferences.count)
            for prefSpecification in preferences {
                if let key = prefSpecification.object(forKey: "Key") {
                    defaultsToRegister.updateValue(prefSpecification.object(forKey: "DefaultValue")!, forKey: key as! String)
                }
            }
            
            let groupDefaults = UserDefaults.init(suiteName: VideoMarksConstants.appGroupID)!
            groupDefaults.register(defaults: defaultsToRegister as [String:Any])
            groupDefaults.synchronize()
            UserDefaults.standard.register(defaults: defaultsToRegister as [String:Any])
            UserDefaults.standard.synchronize()
        }
    }
}
