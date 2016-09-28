//
//  OpenSafariActivity.swift
//  VideoMarks
//
//  Created by nevercry on 6/9/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit



class OpenSafariActivity: UIActivity {
    var URL: Foundation.URL?
    
    let OpenSafari = "VMOpenSafariActivityType"
    
    override var activityType : UIActivityType? {
        return UIActivityType(rawValue: OpenSafari)
    }
    
    override var activityTitle : String? {
        return NSLocalizedString("Open in Safari", comment: "在Safari中打开")
    }
    
    override var activityImage : UIImage? {
        return UIImage.alphaSafariIcon(52, scale: Float(UIScreen.main.scale))
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        
        for item in activityItems {
            if let itemstr = item as? String {
                if let u = Foundation.URL(string: itemstr) {
                    if !(u as NSURL).isFileReferenceURL() {
                        return true
                    }
                }
            } else if let itemUrl = item as? Foundation.URL {
                if !(itemUrl as NSURL).isFileReferenceURL() {
                    return true
                }
            }
        }
        
        return false;
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        var strURL, dURL: Foundation.URL?
        for item in activityItems {
            if let itemstr = item as? String {
                if let u = Foundation.URL(string: itemstr) {
                    if !(u as NSURL).isFileReferenceURL() {
                        strURL = u
                    }
                }
            } else if let itemUrl = item as? Foundation.URL {
                if !(itemUrl as NSURL).isFileReferenceURL() {
                    dURL = itemUrl
                }
            }
        }
        
        self.URL = dURL ?? strURL
    }
    
    override func perform() {
        self.activityDidFinish(UIApplication.shared.openURL(self.URL!))
    }
    
    
    

}
