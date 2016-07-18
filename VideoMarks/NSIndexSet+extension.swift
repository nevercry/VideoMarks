//
//  NSIndexSet+extension.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit


extension NSIndexSet {
    func indexPathsFromIndexesWith(section: Int) -> [NSIndexPath] {
        var indexPaths: [NSIndexPath] = []
        self.enumerateIndexesUsingBlock { (idx, _) in
            indexPaths.append(NSIndexPath(forItem: idx, inSection: section))
        }
        
        return indexPaths
    }
    
}