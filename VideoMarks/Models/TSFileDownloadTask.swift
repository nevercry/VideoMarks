//
//  YoukuTSFileDownloadTask.swift
//  VideoMarks
//
//  Created by nevercry on 8/6/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class TSFileDownloadTask {
    
    init (identifier: String) {
        self.identifier = identifier
    }

    var identifier: String
    var subTasks:[NSURLSessionDownloadTask] = []
    
    var totalWrite: Int64 = 0
    
    var totalTaskCount = 0
    
    var completeTaskCount = 0
    
    var isCombineDone = false
}

