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
    fileprivate var session: Foundation.URLSession?
    
    var taskList:[DownloadTask] = [DownloadTask]()
    
    weak var collection: PHAssetCollection?
    
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "downloadSession")
        self.session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.taskList = [DownloadTask]()
    }
    
    deinit {
        self.session?.invalidateAndCancel()
    }
        
    func newTask(_ url: String) {
        if let url = URL(string: url) {
            let downloadTask = self.session?.downloadTask(with: url)
            downloadTask?.resume()
            
            let task = DownloadTask(url: url, taskIdentifier: downloadTask!.taskIdentifier)
            
            self.taskList.append(task)
        }
    }
}

extension TaskManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let documentURL = VideoMarksConstants.documentURL() {
            let fileManager = FileManager.default
            let destURL = documentURL.appendingPathComponent("tmp.mp4")

            print("destURL is \(destURL)")
                        
            if fileManager.fileExists(atPath: destURL.path) {
                do {
                    try fileManager.removeItem(at: destURL)
                } catch {
                    print("remove item error \(error)")
                }
            }
            
            do {
                try fileManager.moveItem(at: location, to: destURL)
                print("move item to destURL \(destURL)")
            } catch {
                print("error download \(error)")
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: DownloadTaskNotification.Finish.rawValue), object: downloadTask.taskIdentifier)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progressInfo = ["taskIdentifier": downloadTask.taskIdentifier,
                            "totalBytesWritten": NSNumber(value: totalBytesWritten as Int64),
                            "totalBytesExpectedToWrite": NSNumber(value: totalBytesExpectedToWrite as Int64)] as [String : Any]
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: DownloadTaskNotification.Progress.rawValue), object: progressInfo)
    }
}

// MARK: - NSURLSessionDelegate
extension TaskManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            if let completionHandler = appDelegate.backgroundSessionCompletionHandler {
                appDelegate.backgroundSessionCompletionHandler = nil
                DispatchQueue.main.async(execute: {
                    completionHandler()
                })
            }
        }
    }
}
