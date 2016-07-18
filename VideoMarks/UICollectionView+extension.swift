//
//  UICollectionView+extension.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

extension UICollectionView {
    func indexPathsForElementsIn(rect: CGRect) -> [NSIndexPath] {
        let alllayoutAttributes = self.collectionViewLayout.layoutAttributesForElementsInRect(rect)
        guard alllayoutAttributes?.count > 0 else { return [] }
        var indexPaths: [NSIndexPath] = []
        alllayoutAttributes?.forEach({ (layoutAttributes) in
            indexPaths.append(layoutAttributes.indexPath)
        })
        
        return indexPaths
    }
}
