//
//  GirdViewCell.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class GirdViewCell: UICollectionViewCell {
    var thumbnail: UIImage? {
        didSet {
            imageView.image = thumbnail
        }
    }
    var representedAssetIdentifier: String?
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
    

}
