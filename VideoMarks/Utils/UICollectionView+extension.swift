//
//  UICollectionView+extension.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


extension UICollectionView {
    func indexPathsForElementsIn(_ rect: CGRect) -> [IndexPath] {
        let alllayoutAttributes = self.collectionViewLayout.layoutAttributesForElements(in: rect)
        guard alllayoutAttributes?.count > 0 else { return [] }
        var indexPaths: [IndexPath] = []
        alllayoutAttributes?.forEach({ (layoutAttributes) in
            indexPaths.append(layoutAttributes.indexPath)
        })
        
        return indexPaths
    }
}
