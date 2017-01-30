//
//  ArrayDataSource.swift
//  VideoMarks
//
//  Created by nevercry on 9/4/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class ArrayDataSource: NSObject,UITableViewDataSource {
    
    fileprivate var items: [AnyObject]
    fileprivate var cellIdentifier: String
    fileprivate var configureCellBlock: (AnyObject, AnyObject)->Void
    
    init(items: Array<AnyObject>, cellIdentifier: String, configureCellBlock:@escaping (AnyObject,AnyObject)->Void) {
        self.items = items
        self.cellIdentifier = cellIdentifier
        self.configureCellBlock = configureCellBlock
        
        super.init()
    }
    
    func item(atIndexPath indexPath: IndexPath) -> AnyObject {
        return self.items[(indexPath as NSIndexPath).row]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier, for: indexPath)
        let item = self.item(atIndexPath: indexPath)
        self.configureCellBlock(cell, item)
        return cell
    }
}
