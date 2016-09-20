//
//  DownloadStatusView.swift
//  VideoMarks
//
//  Created by nevercry on 8/6/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

protocol DownloadStatusViewDelegate: class {
    func cancel()
}

class DownloadStatusView: UIView {
    
    weak var delegate: DownloadStatusViewDelegate?
    
    @IBOutlet weak var progressLabel: UILabel!
    
    @IBAction func cancelDownload(_ sender: UIButton) {
        delegate?.cancel()
    }
}
