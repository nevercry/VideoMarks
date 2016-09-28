//
//  NSIndexSet+extension.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit


extension IndexSet {
    func indexPathsFromIndexesWith(_ section: Int) -> [IndexPath] {
        var indexPaths: [IndexPath] = []
    
        for (idx,_) in self.enumerated() {
            indexPaths.append(IndexPath(item: idx, section: section))
        }
                
        return indexPaths
    }
    
}
