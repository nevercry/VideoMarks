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
    fileprivate var session: URLSession?
    var taskList:[DownloadTask] = [DownloadTask]()
    
    static let sharedInstance = TaskManager();
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "downloadSession")
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.taskList = [DownloadTask]()
    }
    
    func addNewTask(_ url: URL, collectionId: String) {
        if url.lastPathComponent == "m3u8" {
            let networksession = URLSession(configuration: URLSessionConfiguration.default)
            networksession.dataTask(with: URLRequest(url: url), completionHandler: { (data, res, error) in
                print("解析...")
                guard (data != nil) else {
                    print("m3u8 文件解析失败")
                    return
                }
                // 判断URL属于那个视频网站
                let m3u8Parser = HLSPlayListParser.shareInstance
                var videoFragments: [NSString] // 视频片段地址
                if url.absoluteString.contains("youku.com") {
                    print("url 属于youku")
                    videoFragments = m3u8Parser.youkuParse(data!)
                } else {
                    print("url 未知网站 暂不支持")
                    return
                }
                
                guard videoFragments.count > 0 else {
                    return
                }
                
                self.newGroupTask(videoFragments as [String], collectionId: collectionId)
            }).resume()
        } else {
            self.newTask(url, collectionId: collectionId)
        }
    }
    
    private func newTask(_ url: URL, collectionId: String) {
        let downloadTask = self.session?.downloadTask(with: url)
        downloadTask?.resume()
        let task = DownloadTask(url: url, taskIdentifier: downloadTask!.taskIdentifier, collectionId: collectionId)
        self.taskList.append(task)
        NotificationCenter.default.post(name: VideoMarksConstants.DownloadTaskStart, object: nil)
    }
    
    private func newGroupTask(_ urls: [String], collectionId: String) {
        var taskIds:[Int] = []
        var taskUrls:[URL] = []
        var tasks: [URLSessionTask] = []
        for url in urls {
            let taskUrl = URL(string: url)!
            let downloadTask = self.session!.downloadTask(with: taskUrl)
            taskIds.append(downloadTask.taskIdentifier)
            taskUrls.append(taskUrl)
            tasks.append(downloadTask)
        }
        
        let groupTask = DownloadTask(urls: taskUrls, taskIdentifiers: taskIds, collectionId: collectionId)
        self.taskList.append(groupTask)
        for task in tasks {
            task.resume()
        }
        NotificationCenter.default.post(name: VideoMarksConstants.DownloadTaskStart, object: nil)
    }
    
    func downloadTaskFor(taskId: Int) -> DownloadTask? {
        for downloadTask in self.taskList {
            if downloadTask.haveTask(taskId: taskId) {
                return downloadTask
            }
        }
        return nil
    }
    
    func taskIndexFor(taskId: Int) -> Int? {
        for (index, downloadTask) in self.taskList.enumerated() {
            if downloadTask.haveTask(taskId: taskId) {
                return index
            }
        }
        return nil
    }
    
    func singleFileDidFinishDownload(at location: URL) {
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
    }
    
    func subFile(atIndex taskIndex: Int, didFinishDownloadTo location: URL) {
        if let documentURL = VideoMarksConstants.documentURL() {
            let fileManager = FileManager.default
            let combineDir = documentURL.appendingPathComponent("tmpCombine", isDirectory: true)
            if !fileManager.fileExists(atPath: combineDir.path) {
                do {
                    print("文件夹不存在 创建文件夹")
                    try fileManager.createDirectory(at: combineDir, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print("创建文件夹失败 \(error)")
                }
            }
            print("combineDir is \(combineDir)")
            
            let videoURL = combineDir.appendingPathComponent("\(taskIndex).mp4")
            
            if fileManager.fileExists(atPath: videoURL.path) {
                do {
                    print("删除已存在 \(videoURL) 的文件")
                    try fileManager.removeItem(at: videoURL)
                } catch {
                    print("remove item error \(error)")
                }
            }
            do {
                print("move item to destURL \(videoURL)")
                try fileManager.moveItem(at: location, to: videoURL)
            } catch {
                print("error download \(error)")
            }
        }
    }
    
    
    
    // MARK: - 合并所有视频片段
    func combineAllVideoFragment(withTask task: DownloadTask) {
        print("合并所有视频片段")
        self.backgroundUpdateTask = beginBackgroundUpdateTask()
        guard let documentURL = VideoMarksConstants.documentURL() else { return }
        let fileManager = FileManager.default
        let combineDir = documentURL.appendingPathComponent("tmpCombine", isDirectory: true);
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var previousTime = kCMTimeZero
        
        for i in 0 ..< task.subTaskCount() {
            let videoURL = combineDir.appendingPathComponent("\(i).mp4")
            
            let asset = AVAsset(url: videoURL)
            do {
                print("加入asset \(videoURL)")
                
                // Debug
                let audios = asset.tracks(withMediaType: AVMediaTypeAudio)
                let videos = asset.tracks(withMediaType: AVMediaTypeVideo)
                print("audio tracks is  \(audios) videos is \(videos)")
                print("tracks is \(asset.tracks)")
                
                guard audios.count > 0 && videos.count > 0 else {
                    print("找不到视频")
                    return
                }
                
                try videoTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, end: asset.duration), of: asset.tracks(withMediaType: AVMediaTypeVideo)[0], at: previousTime)
                try audioTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, end: asset.duration), of: asset.tracks(withMediaType: AVMediaTypeAudio)[0], at: previousTime)
            } catch {
                print("加入失败  \(error)")
            }
            previousTime = CMTimeAdd(previousTime, asset.duration)
        }
        
        // 创建exportor
        guard let exportor = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            print("创建ExportSession 失败")
            return
        }
        let exportURL = documentURL.appendingPathComponent("tmp.mp4")
        if fileManager.fileExists(atPath: exportURL.path) {
            do {
                print("文件已存在 删除文件")
                try fileManager.removeItem(at: exportURL)
            } catch {
                print("删除文件失败 \(error)")
            }
        }
        exportor.outputURL = exportURL
        exportor.outputFileType = AVFileTypeMPEG4
        
        exportor.exportAsynchronously {
            DispatchQueue.main.async(execute: {
                if exportor.status == .completed {
                    print("合并成功")
                    self.saveVideoToPhotos(inTask: task)
                    // MARK: 标记合并成功
                    self.clearUpTmpFiles()
                } else {
                    print("导出失败")
                }
            })
        }
        
        endBackgroundUpdateTask()
    }
    
    // MARK: - 合并后的清理工作
    func clearUpTmpFiles() {
        guard let documentURL = VideoMarksConstants.documentURL() else { return }
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
            let fileManager = FileManager.default
            let combineDir = documentURL.appendingPathComponent("tmpCombine", isDirectory: true)
            if fileManager.fileExists(atPath: combineDir.path) {
                do {
                    print("开始删除缓存文件")
                    try fileManager.removeItem(at: combineDir)
                } catch {
                    print("删除缓存失败 \(error)")
                }
                
                print("完成清理")
            }
        }
    }
    
    // MARK: - 保存视频到相册
    func saveVideoToPhotos(inTask task: DownloadTask) {
        print("保存视频到相册")
        guard let documentURL = VideoMarksConstants.documentURL() else { return }
        let fileURL = documentURL.appendingPathComponent("tmp.mp4")
        PHPhotoLibrary.shared().performChanges({
            if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL) {
                let asset = assetChangeRequest.placeholderForCreatedAsset!
                let assets = NSArray(object: asset)
                if let collection = task.fetchAssetCollection(collectionId: task.collectionId) {
                    let collectionChangeRequest = PHAssetCollectionChangeRequest(for: collection)
                    collectionChangeRequest?.addAssets(assets)
                }
            }
        }) { (success, error) in
            guard success == true else {
                print("download Video error \(String(describing: error))")
                return
            }
            
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("error delete")
            }
        }
        
        if let indexTask = self.taskList.index(of: task) {
            print("完成任务 删除task")
            self.taskList.remove(at: indexTask)
        }
        NotificationCenter.default.post(name: VideoMarksConstants.DownloadTaskFinish, object: nil)
    }
    
    // MARK: - 后台任务
    var backgroundUpdateTask = UIBackgroundTaskInvalid
    
    func beginBackgroundUpdateTask() -> UIBackgroundTaskIdentifier {
        return UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.endBackgroundUpdateTask()
        })
    }
    
    func endBackgroundUpdateTask() {
        UIApplication.shared.endBackgroundTask(self.backgroundUpdateTask)
        self.backgroundUpdateTask = UIBackgroundTaskInvalid
    }
}

extension TaskManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let task = self.downloadTaskFor(taskId: downloadTask.taskIdentifier) else { return }
        task.increaseSubTaskComplteCount()
        switch task.type {
        case .singleFile:
            self.singleFileDidFinishDownload(at: location)
            self.saveVideoToPhotos(inTask: task)
        case .groupFile:
            let taskIndex = task.subTaskIndex(withTaskId: downloadTask.taskIdentifier)
            self.subFile(atIndex: taskIndex, didFinishDownloadTo: location)
            if task.isDownloadTaskCompleted {
                self.combineAllVideoFragment(withTask: task)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let task = self.downloadTaskFor(taskId: downloadTask.taskIdentifier) else { return }
        let subProgress = task.fetchSubProgress(withTaskId: downloadTask.taskIdentifier)
        subProgress.totalUnitCount = totalBytesExpectedToWrite
        subProgress.completedUnitCount = totalBytesWritten
        let progressInfo = ["task": task,]
        NotificationCenter.default.post(name: VideoMarksConstants.DownloadTaskProgress, object: progressInfo)
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
