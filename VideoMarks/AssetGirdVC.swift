//
//  AssetGirdVC.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import Photos
import AVKit
import QuartzCore

//private let reuseIdentifier = VideoMarks.GirdViewCellID
private var AssetGirdThumbnailSize: CGSize?

class AssetGirdVC: UICollectionViewController {
    var assetsFetchResults: PHFetchResult?
    var assetCollection: PHAssetCollection?
    var imageManager: PHCachingImageManager?
    var previousPreheatRect: CGRect?
    
    var taskManager = TaskManager()
    
    @IBOutlet var m3u8DownloadStatusView: DownloadStatusView!
    
    var tsFileDownloadTask: TSFileDownloadTask?
    
    lazy var m3u8_session: NSURLSession = {
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("m3u8_backgroundSession")
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        return session
    }()
    
    override func awakeFromNib() {
        imageManager = PHCachingImageManager()
        resetCachedAssets()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit {
        // 注销通知
        
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let scale = UIScreen.mainScreen().scale
        let flowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        
        // 去设备最小尺寸来显示Cell 考虑横屏时的情况
        let minWidth = min(UIScreen.mainScreen().bounds.width, UIScreen.mainScreen().bounds.height)
        let itemWidth = minWidth / 4
        flowLayout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        let cellSize = flowLayout.itemSize
        
        AssetGirdThumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale )
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updateCachedAssets()
        
        if let _ = assetCollection {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(addVideo))
            taskManager.collection = assetCollection!
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 注册通知
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(downloadFinished), name: DownloadTaskNotification.Finish.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(downloading), name: DownloadTaskNotification.Progress.rawValue, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    func addVideo(sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: NSLocalizedString("Enter the URL for the video you want to save.", comment: "输入你想要保存的视频地址"), message: nil, preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler { (textField) in
            textField.keyboardType = .URL
            textField.placeholder = "Video URL"
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .Cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: "保存"), style: .Default, handler: { [weak self] (action) in
            // 添加下载任务
            guard let videoUrl = alertController.textFields?.first?.text, let vURL = NSURL(string: videoUrl) where videoUrl.isEmpty != true else { return }
            // 验证URL 是否包含m3u8
            print("lastComponent is \(vURL.lastPathComponent)")
            
            if vURL.lastPathComponent == "m3u8" {
                self?.show_m3u8_downloadStatusView()
                
                let networksession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
                
                networksession.dataTaskWithRequest(NSURLRequest(URL: vURL), completionHandler: { (data, res, error) in
                    dispatch_async(dispatch_get_main_queue(), {
                        self?.m3u8DownloadStatusView.progressLabel.text = NSLocalizedString("Parsing", comment: "解析...")
                    })
                    
                    guard (data != nil) else {
                        print("m3u8 文件解析失败")
                        dispatch_async(dispatch_get_main_queue(), {
                            self?.hide_m3u8_downloadStatusView()
                        })
                        return
                    }
                    
                    // 判断URL属于那个视频网站
                    let m3u8Parser = HLSPlayListParser.shareInstance
                    
                    var videoFragments: [NSString] // 视频片段地址
                    if videoUrl.containsString("youku.com") {
                        print("url 属于youku")
                        videoFragments = m3u8Parser.youkuParse(data!)
                    } else {
                        print("url 未知网站")
                        videoFragments = m3u8Parser.otherParse(data!)
                    }
                    
                    guard videoFragments.count > 0 else {
                        dispatch_async(dispatch_get_main_queue(), {
                            self?.hide_m3u8_downloadStatusView()
                        })
                        return
                    }
                    
                    // 下载所有视频片段
                    dispatch_async(dispatch_get_main_queue(), {
                        self?.downloadAllVideoFragments(videoFragments)
                    })
                }).resume()
            } else {
                self?.taskManager.newTask(videoUrl)
                self?.collectionView?.reloadData()
            }
            }))
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    func downloadFinished(note: NSNotification) {
        // 下载完成
        guard let taskID = note.object as? Int, taskIdx = taskIndex(taskID) else { return }

        // 删除对应的任务
        taskManager.taskList.removeAtIndex(taskIdx)
        
        print("now the taskList count is \(taskManager.taskList.count)")
        
        dispatch_async(dispatch_get_main_queue()) { 
            self.collectionView?.reloadData()
        }
        
        saveVideoToPhotos()
    }
    
    func downloading(note: NSNotification) {
        // 下载中
        if let progressInfo: [String: AnyObject] = note.object as? [String: AnyObject] {
            guard let taskID = progressInfo["taskIdentifier"] as? Int,
            totalBytesWritten = progressInfo["totalBytesWritten"] as? NSNumber,
                totalBytesExpectedToWrite = progressInfo["totalBytesExpectedToWrite"] as? NSNumber else { return }
            // 获得对应的Cell
            if let taskIdx = taskIndex(taskID) {
                if let cell = collectionView?.cellForItemAtIndexPath(NSIndexPath(forItem: taskIdx, inSection: 1)) as? DownloadViewCell {
                    cell.progressLabel.text = "\(totalBytesWritten.integerValue * 100 / totalBytesExpectedToWrite.integerValue)%"
                }
            }
        }
    }
    
    func taskIndex(taskID: Int) -> Int? {
        for (index, task) in taskManager.taskList.enumerate() {
            if task.taskIdentifier == taskID {
                return index
            }
        }
        return nil
    }
    
    // MARK: - Show Download m3u8 
    func show_m3u8_downloadStatusView() {
        // 初始化Layout
        self.collectionView?.userInteractionEnabled = false
        m3u8DownloadStatusView.layer.cornerRadius = 10
        self.navigationItem.rightBarButtonItem?.enabled = false
        
        self.view.addSubview(m3u8DownloadStatusView)
        m3u8DownloadStatusView.delegate = self
        
        m3u8DownloadStatusView.translatesAutoresizingMaskIntoConstraints = false
        
        let constrainCenterX = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .CenterX, relatedBy: .Equal, toItem: self.collectionView, attribute: .CenterX, multiplier: 1, constant: 0)
        
        let constrainCenterY = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .CenterY, relatedBy: .Equal, toItem: self.collectionView, attribute: .CenterY, multiplier: 1, constant: 0)
        
        let constrainWidth = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 200)
        let constrainHeigh = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 200)
        
        NSLayoutConstraint.activateConstraints([constrainCenterX,constrainCenterY,constrainWidth,constrainHeigh])
    }
    
    // MARK: - Hide Download m3u8
    func hide_m3u8_downloadStatusView() {
        // 取消下载
        self.collectionView?.userInteractionEnabled = true
        self.navigationItem.rightBarButtonItem?.enabled = true
        print("取消下载")
        self.m3u8_session.invalidateAndCancel()
        
        UIView.animateWithDuration(0.3, animations: {
            self.m3u8DownloadStatusView.alpha = 0
        }) { (success) in
            self.m3u8DownloadStatusView.removeFromSuperview()
            self.m3u8DownloadStatusView.alpha = 1
        }
    }
    
    // MARK: - 下载所有视频片段
    func downloadAllVideoFragments(urls: [NSString]) {
        print("开始下载所有视频片段")
        // 初始化task
        let newDownloadTask = TSFileDownloadTask(identifier: "TSFileDownload")
        
        newDownloadTask.totalTaskCount = urls.count
        m3u8DownloadStatusView.progressLabel.text = "\(newDownloadTask.completeTaskCount)/\(newDownloadTask.totalTaskCount)"
        print("总共有 \(newDownloadTask.totalTaskCount) 个文件需要下载")
        
        for url in urls {
            guard let videoURL = NSURL(string: url as String) else {
                print("下载地址有误 error")
                hide_m3u8_downloadStatusView()
                return
            }
            let downloadTask = m3u8_session.downloadTaskWithURL(videoURL)
            newDownloadTask.subTasks.append(downloadTask)
        }
        
        defer {
            for task in newDownloadTask.subTasks {
                task.resume()
            }
            
            tsFileDownloadTask = newDownloadTask
        }
    }
    
    // MARK: - 合并所有视频片段
    func combineAllVideoFragment() {
        print("合并所有视频片段")
        m3u8DownloadStatusView.progressLabel.text = NSLocalizedString("Processing", comment: "处理中...")
        guard let documentURL = VideoMarks.documentURL() else { return }
        
        let fileManager = NSFileManager.defaultManager()
        let combineDir = documentURL.URLByAppendingPathComponent("tmpCombine", isDirectory: true)
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var previousTime = kCMTimeZero
        
        guard let tsTask = tsFileDownloadTask else {
            print("tsFileDownloadTask is nil")
            return
        }
    
        for i in 0 ..< tsTask.totalTaskCount {
            let videoURL = combineDir.URLByAppendingPathComponent("\(i).mp4")
            
            let asset = AVAsset(URL: videoURL)
            do {
                print("加入asset \(videoURL)")
                
                // Debug
                let audios = asset.tracksWithMediaType(AVMediaTypeAudio)
                let videos = asset.tracksWithMediaType(AVMediaTypeVideo)
                print("audio tracks is  \(audios) videos is \(videos)")
                print("tracks is \(asset.tracks)")
                
                guard audios.count > 0 && videos.count > 0 else {
                    print("找不到视频")
                    self.hide_m3u8_downloadStatusView()
                    return
                }
                
                try videoTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, end: asset.duration), ofTrack: asset.tracksWithMediaType(AVMediaTypeVideo)[0], atTime: previousTime)
                try audioTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, end: asset.duration), ofTrack: asset.tracksWithMediaType(AVMediaTypeAudio)[0], atTime: previousTime)
            } catch {
                print("加入失败  \(error)")
                self.hide_m3u8_downloadStatusView()
            }
            previousTime = CMTimeAdd(previousTime, asset.duration)
        }
        
        // 创建exportor
        guard let exportor = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            print("创建ExportSession 失败")
            self.hide_m3u8_downloadStatusView()
            return
        }
        
        let exportURL = documentURL.URLByAppendingPathComponent("tmp.mp4")
        
        if fileManager.fileExistsAtPath(exportURL.path!) {
            do {
                print("文件已存在 删除文件")
                try fileManager.removeItemAtURL(exportURL)
            } catch {
                print("删除文件失败 \(error)")
                self.hide_m3u8_downloadStatusView()
            }
        }
        
        exportor.outputURL = exportURL
        exportor.outputFileType = AVFileTypeMPEG4
        
        exportor.exportAsynchronouslyWithCompletionHandler { 
            dispatch_async(dispatch_get_main_queue(), {
                if exportor.status == .Completed {
                    print("合并成功")
                    // MARK: 标记合并成功
                    tsTask.isCombineDone = true
                    self.clearUpTmpFiles()
                } else {
                    print("导出失败")
                    self.hide_m3u8_downloadStatusView()
                }
            })
        }
    }
    
    
    // MARK: - 合并后的清理工作
    func clearUpTmpFiles() {
        
        guard let documentURL = VideoMarks.documentURL() else { return }
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            let fileManager = NSFileManager.defaultManager()
            let combineDir = documentURL.URLByAppendingPathComponent("tmpCombine", isDirectory: true)
            if fileManager.fileExistsAtPath(combineDir.path!) {
                do {
                    print("开始删除缓存文件")
                    try fileManager.removeItemAtURL(combineDir)
                } catch {
                    print("删除缓存失败 \(error)")
                }
                
                print("完成清理")
            }
        }
        
        hide_m3u8_downloadStatusView()
        
        // 把视频文件导入到相册
        saveVideoToPhotos()
    }
    
    // MARK: - 保存视频到相册
    func saveVideoToPhotos() {
        print("保存视频到相册")
        guard let documentURL = VideoMarks.documentURL() else { return }
        
        let fileURL = documentURL.URLByAppendingPathComponent("tmp.mp4")
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(fileURL) {
                let collectionChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: self.assetCollection!)
                collectionChangeRequest?.addAssets([assetChangeRequest.placeholderForCreatedAsset!])
            }
        }) { (success, error) in
            guard success == true else {
                print("download Video error \(error)")
                return
            }
            
            do {
                try NSFileManager.defaultManager().removeItemAtURL(fileURL)
            } catch {
                print("error delete")
            }
            
            dispatch_async(dispatch_get_main_queue(), { 
                self.finishTSDownloadTask()
            })
        }
    }
    
    // MARK: - 完成下载TSFile的任务
    func finishTSDownloadTask() {
        tsFileDownloadTask = nil
        print("清楚下载任务")
    }
    
    // MARK: - Asset Caching
    func resetCachedAssets()  {
        imageManager?.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRectZero
    }
    
    func updateCachedAssets() {
        let isVisible = self.isViewLoaded() && self.view.window != nil
        
        guard isVisible else {
            return
        }
        
        var preheatRect = self.collectionView?.bounds
        let preHeight = CGRectGetHeight(preheatRect!)
        
        preheatRect = CGRectInset(preheatRect!, 0.0, -0.5 * preHeight)
        
        let delta = abs(CGRectGetMidY(preheatRect!) - CGRectGetMidY(self.previousPreheatRect!))
        if delta > CGRectGetHeight(self.collectionView!.bounds) / 3.0 {
            var addedIndexPaths: [NSIndexPath] = []
            var removedIndexPaths: [NSIndexPath] = []
            self.computeDifferenceBetween(self.previousPreheatRect!, andNewRect: preheatRect!, removedHandler: { (removedRect) in
                let indexPaths = self.collectionView!.indexPathsForElementsIn(removedRect)
                removedIndexPaths.appendContentsOf(indexPaths)
                }, addedHandler: { (addedRect) in
                    let indexPaths = self.collectionView!.indexPathsForElementsIn(addedRect)
                    addedIndexPaths.appendContentsOf(indexPaths)
            })
            
            let assetsToStartCaching = self.assetsAt(addedIndexPaths)
            let assetsToStopCaching = self.assetsAt(removedIndexPaths)
            
            self.imageManager?.stopCachingImagesForAssets(assetsToStopCaching, targetSize: AssetGirdThumbnailSize!, contentMode: .AspectFill, options: nil)
            self.imageManager?.startCachingImagesForAssets(assetsToStartCaching, targetSize: AssetGirdThumbnailSize!, contentMode: .AspectFill, options: nil)
            
            self.previousPreheatRect  = preheatRect
        }
    }
    
    func computeDifferenceBetween(oldRect: CGRect, andNewRect newRect: CGRect, removedHandler: (removedRect: CGRect)-> Void, addedHandler: (addedRect: CGRect) -> Void ) {
        if CGRectIntersectsRect(oldRect, newRect) {
            let oldMaxY =  CGRectGetMaxY(oldRect)
            let oldMinY = CGRectGetMinY(oldRect)
            let newMaxY = CGRectGetMaxY(newRect)
            let newMinY = CGRectGetMinY(newRect)
            
            if (newMaxY > oldMaxY) {
                let rectToAdd = CGRect(x: newRect.origin.x, y: oldMaxY, width: newRect.size.width, height: (newMaxY - oldMaxY))
                addedHandler(addedRect: rectToAdd)
            }
            
            if (oldMinY > newMinY) {
                let rectToAdd = CGRect(x: newRect.origin.x, y: newMinY, width: newRect.size.width, height: (oldMinY - newMinY))
                addedHandler(addedRect: rectToAdd)
            }
            
            if (newMaxY < oldMaxY) {
                let rectToRemoved = CGRect(x: newRect.origin.x, y: newMaxY, width: newRect.size.width, height: (oldMaxY - newMaxY))
                removedHandler(removedRect: rectToRemoved)
            }
            
            if (oldMinY < newMinY) {
                let rectToRemoved = CGRect(x: newRect.origin.x, y: oldMinY, width: newRect.size.width, height: (newMinY - oldMinY))
                removedHandler(removedRect: rectToRemoved)
            }
        } else {
            addedHandler(addedRect: newRect)
            removedHandler(removedRect: oldRect)
        }
    }
    
    func assetsAt(indexPaths: [NSIndexPath]) -> [PHAsset] {
        guard indexPaths.count > 0 else { return [] }
        
        var assets: [PHAsset] = []
        indexPaths.forEach { (idx) in
            if idx.section == 0 {
                let asset = self.assetsFetchResults![idx.item] as! PHAsset
                assets.append(asset)
            }
        }
        
        return assets
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var numberOfItems: Int
        if section == 0 {
            numberOfItems = self.assetsFetchResults?.count ?? 0
        } else {
            numberOfItems = self.taskManager.taskList.count ?? 0
        }
        
        return numberOfItems
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var collectionViewCell: UICollectionViewCell
        
        if indexPath.section == 0 {
            let asset = self.assetsFetchResults![indexPath.item] as! PHAsset
            
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier("GirdViewCell", forIndexPath: indexPath) as! GirdViewCell
            cell.representedAssetIdentifier = asset.localIdentifier
            
            self.imageManager?.requestImageForAsset(asset, targetSize: AssetGirdThumbnailSize!, contentMode: .AspectFill, options: nil, resultHandler: { (image, info) in
                if cell.representedAssetIdentifier == asset.localIdentifier {
                    cell.thumbnail = image
                }
            })
            
            collectionViewCell = cell
        } else {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier("DownloadViewCell", forIndexPath: indexPath) as! DownloadViewCell
            
            // 设置DownloadCell...
            collectionViewCell = cell
        }
        
        // Configure the cell
    
        return collectionViewCell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            let asset = self.assetsFetchResults![indexPath.item] as! PHAsset
            let videoRequestOptions = PHVideoRequestOptions()
            videoRequestOptions.deliveryMode = .HighQualityFormat
            
            self.imageManager?.requestPlayerItemForVideo(asset, options: videoRequestOptions, resultHandler: { (avplayerItem, info) in
                let player = AVPlayer(playerItem: avplayerItem!)
                PlayerController.sharedInstance.playVideo(player, inViewController: self)
            })
        }
    }
}

extension AssetGirdVC: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(changeInstance: PHChange) {
        guard self.assetsFetchResults != nil else { return }
        if let collectionChanges = changeInstance.changeDetailsForFetchResult(self.assetsFetchResults!) {
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                self?.assetsFetchResults = collectionChanges.fetchResultAfterChanges
                if !collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves {
                    self?.collectionView?.reloadData()
                } else {
                    self?.collectionView?.performBatchUpdates({
                        if let removedIndexes = collectionChanges.removedIndexes where removedIndexes.count > 0 {
                            self?.collectionView?.deleteItemsAtIndexPaths(removedIndexes.indexPathsFromIndexesWith(0))
                        }
                        
                        if let insertedIndexes = collectionChanges.insertedIndexes where insertedIndexes.count > 0 {
                            self?.collectionView?.insertItemsAtIndexPaths(insertedIndexes.indexPathsFromIndexesWith(0))
                        }
                        
                        if let changedIndexes = collectionChanges.changedIndexes where changedIndexes.count > 0 {
                            self?.collectionView?.reloadItemsAtIndexPaths(changedIndexes.indexPathsFromIndexesWith(0))
                        }
                        
                        }, completion:nil)
                }
                self?.resetCachedAssets()
            })
        }
    }
}

extension AssetGirdVC: DownloadStatusViewDelegate {
    func cancel() {
        // 取消下载
        self.hide_m3u8_downloadStatusView()
    }
}

extension AssetGirdVC: NSURLSessionDownloadDelegate {
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        // 完成下载
        print("完成下载 文件在\(location)")
        
        guard let tsTask = tsFileDownloadTask else {
            print("tsFileDownloadTas 为nil")
            return
        }
        
        tsTask.completeTaskCount += 1
        
        let totalSizeWrite = NSByteCountFormatter.stringFromByteCount(tsTask.totalWrite, countStyle: .Binary)
        dispatch_async(dispatch_get_main_queue()) {
            self.m3u8DownloadStatusView.progressLabel.text = "\(tsTask.completeTaskCount)/\(tsTask.totalTaskCount) \(totalSizeWrite)"
        }
        
        print("已下载 \(tsTask.completeTaskCount) 个")
        
        if let documentURL = VideoMarks.documentURL() {
            let fileManager = NSFileManager.defaultManager()
            let combineDir = documentURL.URLByAppendingPathComponent("tmpCombine", isDirectory: true)
            
            if !fileManager.fileExistsAtPath(combineDir.path!) {
                do {
                    print("文件夹不存在 创建文件夹")
                    try fileManager.createDirectoryAtURL(combineDir, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print("创建文件夹失败 \(error)")
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.hide_m3u8_downloadStatusView()
                    }
                }
            }
            
            print("combineDir is \(combineDir)")
            
            var indexVideo: Int = -1
            
            for (idx,task) in tsTask.subTasks.enumerate() {
                if task.taskIdentifier == downloadTask.taskIdentifier {
                    indexVideo = idx
                    break
                }
            }
            
            guard indexVideo != -1 else {
                print("下载任务index 出错")
                dispatch_async(dispatch_get_main_queue()) {
                    self.hide_m3u8_downloadStatusView()
                }
                return
            }
            
            print("the idx is \(indexVideo)")
            
            let videoURL = combineDir.URLByAppendingPathComponent("\(indexVideo).mp4")
            
            if fileManager.fileExistsAtPath(videoURL.path!) {
                do {
                    print("删除已存在 \(videoURL) 的文件")
                    try fileManager.removeItemAtURL(videoURL)
                } catch {
                    print("remove item error \(error)")
                    dispatch_async(dispatch_get_main_queue()) {
                        self.hide_m3u8_downloadStatusView()
                    }
                }
            }
            
            do {
                print("move item to destURL \(videoURL)")
                try fileManager.moveItemAtURL(location, toURL: videoURL)
            } catch {
                print("error download \(error)")
                dispatch_async(dispatch_get_main_queue()) {
                    self.hide_m3u8_downloadStatusView()
                }
            }
        }
        
        if tsTask.completeTaskCount == tsTask.totalTaskCount {
            print("全部下载完 开始合并文件")
            dispatch_async(dispatch_get_main_queue(), {
                self.combineAllVideoFragment()
            })
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // 恢复下载
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 写入
        
        guard let task = tsFileDownloadTask else {
            print("tsFileDownloadTas 为nil")
            return
        }
        
        task.totalWrite += bytesWritten
        
        let totalSizeWrite = NSByteCountFormatter.stringFromByteCount(task.totalWrite, countStyle: .Binary)
        
        dispatch_async(dispatch_get_main_queue()) { 
            self.m3u8DownloadStatusView.progressLabel.text = "\(task.completeTaskCount)/\(task.totalTaskCount) \(totalSizeWrite)"
        }
        
    }
}

extension AssetGirdVC: NSURLSessionDelegate {
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