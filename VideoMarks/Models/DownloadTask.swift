//
//  DownloadTask.swift
//  VideoMarks
//
//  Created by nevercry on 7/25/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import Photos

struct DownloadTask {
    var url: NSURL
    var taskIdentifier: Int
    
    init(url: NSURL, taskIdentifier: Int) {
        self.url = url
        self.taskIdentifier = taskIdentifier
    }
}