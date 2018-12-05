//
//  MemoryCache.swift
//  VideoMarks
//
//  Created by nevercry on 8/28/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class MemoryCache: NSCache<AnyObject, AnyObject> {
    
    static let shareInstance = MemoryCache()
    
    override init() {
        super.init()
        
         NotificationCenter.default.addObserver(self, selector: #selector(clearMemory), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    
    @objc func clearMemory() {
        self.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
