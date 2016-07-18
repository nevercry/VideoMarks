//
//  OpenSafariActivity.swift
//  VideoMarks
//
//  Created by nevercry on 6/9/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit



class OpenSafariActivity: UIActivity {
    var URL: NSURL?
    
    let OpenSafari = "VMOpenSafariActivityType"
    
    override func activityType() -> String? {
        return OpenSafari
    }
    
    override func activityTitle() -> String? {
        return NSLocalizedString("Open in Safari", comment: "在Safari中打开")
    }
    
    override func activityImage() -> UIImage? {
        return UIImage.alphaSafariIcon(52, scale: Float(UIScreen.mainScreen().scale))
    }
    
    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        
        for item in activityItems {
            if let itemstr = item as? String {
                if let u = NSURL(string: itemstr) {
                    if !u.isFileReferenceURL() {
                        return true
                    }
                }
            } else if let itemUrl = item as? NSURL {
                if !itemUrl.isFileReferenceURL() {
                    return true
                }
            }
        }
        
        return false;
    }
    
    override func prepareWithActivityItems(activityItems: [AnyObject]) {
        var strURL, dURL: NSURL?
        for item in activityItems {
            if let itemstr = item as? String {
                if let u = NSURL(string: itemstr) {
                    if !u.isFileReferenceURL() {
                        strURL = u
                    }
                }
            } else if let itemUrl = item as? NSURL {
                if !itemUrl.isFileReferenceURL() {
                    dURL = itemUrl
                }
            }
        }
        
        self.URL = dURL ?? strURL
    }
    
    override func performActivity() {
        self.activityDidFinish(UIApplication.sharedApplication().openURL(self.URL!))
    }
    
    
    

}
