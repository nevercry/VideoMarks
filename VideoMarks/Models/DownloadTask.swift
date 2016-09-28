//
//  DownloadTask.swift
//  VideoMarks
//
//  Created by nevercry on 7/25/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import Photos

enum DonwnloadTaskType {
    case singleFile
    case groupFile
}

class DownloadTask: NSObject {
    var type: DonwnloadTaskType
    var collectionId: String
    var progress: Progress
    private var subProgressTable: [Progress] = []
    
    var isDownloadTaskCompleted: Bool  {
        return self.taskCompletedCount == self.taskIdentifiers.count
    }

    private var urls: [URL] = []
    private var taskIdentifiers: [Int] = []
    private var taskCompletedCount = 0
    
    init(urls: [URL], taskIdentifiers: [Int], collectionId: String) {
        self.urls = urls
        self.taskIdentifiers = taskIdentifiers
        self.type = .groupFile
        self.collectionId = collectionId
        self.progress = Progress(totalUnitCount: Int64(taskIdentifiers.count))
        for _ in 0 ..< taskIdentifiers.count {
            let subProgress = Progress(totalUnitCount: 0)
            self.progress.addChild(subProgress, withPendingUnitCount: 1)
            self.subProgressTable.append(subProgress)
        }        
        super.init()
    }
    
    convenience init(url: URL, taskIdentifier: Int, collectionId: String) {
        self.init(urls: [url], taskIdentifiers: [taskIdentifier], collectionId: collectionId)
        self.type = .singleFile
    }
    
    func increaseSubTaskComplteCount() {
        if self.taskCompletedCount < self.taskIdentifiers.count {
            self.taskCompletedCount += 1
        }
    }
    
    func haveTask(taskId: Int) -> Bool {
        return self.taskIdentifiers.contains(taskId)
    }
    
    func subTaskIndex(withTaskId taskId: Int) -> Int {
        return self.taskIdentifiers.index(of: taskId)!
    }
    
    func fetchAssetCollection(collectionId: String) -> PHAssetCollection? {
        let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionId], options: nil).firstObject
        return collection;
    }
    
    func subTaskCount() -> Int {
        return self.taskIdentifiers.count
    }
    
    func fetchSubProgress(withTaskId taskId: Int) -> Progress {
        let taskIndex = self.subTaskIndex(withTaskId: taskId)
        return self.subProgressTable[taskIndex]
    }
    
}


