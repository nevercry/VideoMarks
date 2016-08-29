//
//  MemoryCache.swift
//  VideoMarks
//
//  Created by nevercry on 8/28/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class MemoryCache: NSCache {
    
    static let shareInstance = MemoryCache()
    
    override init() {
        super.init()
        
         NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(clearMemory), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    func clearMemory() {
        self.removeAllObjects()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}