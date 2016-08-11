//
//  TaskManager.swift
//  VideoMarks
//
//  Created by nevercry on 7/25/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import Photos

class TaskManager: NSObject {
    private var session: NSURLSession?
    
    var taskList:[DownloadTask] = [DownloadTask]()
    
    weak var collection: PHAssetCollection?
    
    override init() {
        super.init()
        
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("downloadSession")
        self.session = NSURLSession(configuration: config, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        self.taskList = [DownloadTask]()
    }
    
    deinit {
        self.session?.invalidateAndCancel()
    }
        
    func newTask(url: String) {
        if let url = NSURL(string: url) {
            let downloadTask = self.session?.downloadTaskWithURL(url)
            downloadTask?.resume()
            
            let task = DownloadTask(url: url, taskIdentifier: downloadTask!.taskIdentifier)
            
            self.taskList.append(task)
        }
    }
}

extension TaskManager: NSURLSessionDownloadDelegate {
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        
        if let documentURL = VideoMarks.documentURL() {
            let fileManager = NSFileManager.defaultManager()
            let destURL = documentURL.URLByAppendingPathComponent("tmp.mp4")
            print("destURL is \(destURL)")
                        
            if fileManager.fileExistsAtPath(destURL.path!) {
                do {
                    try fileManager.removeItemAtURL(destURL)
                } catch {
                    print("remove item error \(error)")
                }
            }
            
            do {
                try fileManager.moveItemAtURL(location, toURL: destURL)
                print("move item to destURL \(destURL)")
            } catch {
                print("error download \(error)")
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(DownloadTaskNotification.Finish.rawValue, object: downloadTask.taskIdentifier)
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progressInfo = ["taskIdentifier": downloadTask.taskIdentifier,
                            "totalBytesWritten": NSNumber(longLong: totalBytesWritten),
                            "totalBytesExpectedToWrite": NSNumber(longLong: totalBytesExpectedToWrite)]
        
        NSNotificationCenter.defaultCenter().postNotificationName(DownloadTaskNotification.Progress.rawValue, object: progressInfo)
    }
}

// MARK: - NSURLSessionDelegate
extension TaskManager: NSURLSessionDelegate {
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            if let completionHandler = appDelegate.backgroundSessionCompletionHandler {
                appDelegate.backgroundSessionCompletionHandler = nil
                dispatch_async(dispatch_get_main_queue(), {
                    completionHandler()
                })
            }
        }
    }
}