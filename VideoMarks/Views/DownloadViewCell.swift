//
//  DownloadViewCell.swift
//  VideoMarks
//
//  Created by nevercry on 7/25/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class DownloadViewCell: UICollectionViewCell {
    @IBOutlet weak var progressLabel: UILabel!
    
    
    override func prepareForReuse() {
        super.prepareForReuse()
        progressLabel.text = NSLocalizedString("Downloading", comment: "下载中")
    }


}
