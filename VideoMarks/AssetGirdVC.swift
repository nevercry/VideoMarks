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
    var assetsFetchResults: PHFetchResult<AnyObject>?
    var assetCollection: PHAssetCollection?
    var imageManager: PHCachingImageManager?
    var previousPreheatRect: CGRect?
    
    var taskManager = TaskManager()
    
    @IBOutlet var m3u8DownloadStatusView: DownloadStatusView!
    
    var tsFileDownloadTask: TSFileDownloadTask?
    
    lazy var m3u8_session: Foundation.URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "m3u8_backgroundSession")
        let session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        return session
    }()
    
    override func awakeFromNib() {
        imageManager = PHCachingImageManager()
        resetCachedAssets()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        // 注销通知
        
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let scale = UIScreen.main.scale
        let flowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        
        // 去设备最小尺寸来显示Cell 考虑横屏时的情况
        let minWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let itemWidth = minWidth / 4
        flowLayout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        let cellSize = flowLayout.itemSize
        
        AssetGirdThumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updateCachedAssets()
        
        if let _ = assetCollection {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addVideo))
            taskManager.collection = assetCollection!
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 注册通知
        NotificationCenter.default.addObserver(self, selector: #selector(downloadFinished), name: NSNotification.Name(rawValue: DownloadTaskNotification.Finish.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloading), name: NSNotification.Name(rawValue: DownloadTaskNotification.Progress.rawValue), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    func addVideo(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: NSLocalizedString("Enter the URL for the video you want to save.", comment: "输入你想要保存的视频地址"), message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.keyboardType = .URL
            textField.placeholder = "Video URL"
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: "保存"), style: .default, handler: { [weak self] (action) in
            // 添加下载任务
            guard let videoUrl = alertController.textFields?.first?.text, let vURL = URL(string: videoUrl) , videoUrl.isEmpty != true else { return }
            // 验证URL 是否包含m3u8
            print("lastComponent is \(vURL.lastPathComponent)")
            
            if vURL.lastPathComponent == "m3u8" {
                self?.show_m3u8_downloadStatusView()
                
                let networksession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
                
                networksession.dataTask(with: URLRequest(url: vURL), completionHandler: { (data, res, error) in
                    DispatchQueue.main.async(execute: {
                        self?.m3u8DownloadStatusView.progressLabel.text = NSLocalizedString("Parsing", comment: "解析...")
                    })
                    
                    guard (data != nil) else {
                        print("m3u8 文件解析失败")
                        DispatchQueue.main.async(execute: {
                            self?.hide_m3u8_downloadStatusView()
                        })
                        return
                    }
                    
                    // 判断URL属于那个视频网站
                    let m3u8Parser = HLSPlayListParser.shareInstance
                    
                    var videoFragments: [NSString] // 视频片段地址
                    if videoUrl.contains("youku.com") {
                        print("url 属于youku")
                        videoFragments = m3u8Parser.youkuParse(data!)
                    } else {
                        print("url 未知网站")
                        videoFragments = m3u8Parser.otherParse(data!)
                    }
                    
                    guard videoFragments.count > 0 else {
                        DispatchQueue.main.async(execute: {
                            self?.hide_m3u8_downloadStatusView()
                        })
                        return
                    }
                    
                    // 下载所有视频片段
                    DispatchQueue.main.async(execute: {
                        self?.downloadAllVideoFragments(videoFragments)
                    })
                }).resume()
            } else {
                self?.taskManager.newTask(videoUrl)
                self?.collectionView?.reloadData()
            }
            }))
        present(alertController, animated: true, completion: nil)
    }
    
    func downloadFinished(_ note: Notification) {
        // 下载完成
        guard let taskID = note.object as? Int, let taskIdx = taskIndex(taskID) else { return }

        // 删除对应的任务
        taskManager.taskList.remove(at: taskIdx)
        
        print("now the taskList count is \(taskManager.taskList.count)")
        
        DispatchQueue.main.async { 
            self.collectionView?.reloadData()
        }
        
        saveVideoToPhotos()
    }
    
    func downloading(_ note: Notification) {
        // 下载中
        if let progressInfo: [String: AnyObject] = note.object as? [String: AnyObject] {
            guard let taskID = progressInfo["taskIdentifier"] as? Int,
            let totalBytesWritten = progressInfo["totalBytesWritten"] as? NSNumber,
                let totalBytesExpectedToWrite = progressInfo["totalBytesExpectedToWrite"] as? NSNumber else { return }
            // 获得对应的Cell
            if let taskIdx = taskIndex(taskID) {
                if let cell = collectionView?.cellForItem(at: IndexPath(item: taskIdx, section: 1)) as? DownloadViewCell {
                    cell.progressLabel.text = "\(totalBytesWritten.intValue * 100 / totalBytesExpectedToWrite.intValue)%"
                }
            }
        }
    }
    
    func taskIndex(_ taskID: Int) -> Int? {
        for (index, task) in taskManager.taskList.enumerated() {
            if task.taskIdentifier == taskID {
                return index
            }
        }
        return nil
    }
    
    // MARK: - Show Download m3u8 
    func show_m3u8_downloadStatusView() {
        // 初始化Layout
        self.collectionView?.isUserInteractionEnabled = false
        m3u8DownloadStatusView.layer.cornerRadius = 10
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        self.view.addSubview(m3u8DownloadStatusView)
        m3u8DownloadStatusView.delegate = self
        
        m3u8DownloadStatusView.translatesAutoresizingMaskIntoConstraints = false
        
        let constrainCenterX = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .centerX, relatedBy: .equal, toItem: self.collectionView, attribute: .centerX, multiplier: 1, constant: 0)
        
        let constrainCenterY = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .centerY, relatedBy: .equal, toItem: self.collectionView, attribute: .centerY, multiplier: 1, constant: 0)
        
        let constrainWidth = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
        let constrainHeigh = NSLayoutConstraint(item: m3u8DownloadStatusView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
        
        NSLayoutConstraint.activate([constrainCenterX,constrainCenterY,constrainWidth,constrainHeigh])
    }
    
    // MARK: - Hide Download m3u8
    func hide_m3u8_downloadStatusView() {
        // 取消下载
        self.collectionView?.isUserInteractionEnabled = true
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        print("取消下载")
        self.m3u8_session.invalidateAndCancel()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.m3u8DownloadStatusView.alpha = 0
        }, completion: { (success) in
            self.m3u8DownloadStatusView.removeFromSuperview()
            self.m3u8DownloadStatusView.alpha = 1
        }) 
    }
    
    // MARK: - 下载所有视频片段
    func downloadAllVideoFragments(_ urls: [NSString]) {
        print("开始下载所有视频片段")
        // 初始化task
        let newDownloadTask = TSFileDownloadTask(identifier: "TSFileDownload")
        
        newDownloadTask.totalTaskCount = urls.count
        m3u8DownloadStatusView.progressLabel.text = "\(newDownloadTask.completeTaskCount)/\(newDownloadTask.totalTaskCount)"
        print("总共有 \(newDownloadTask.totalTaskCount) 个文件需要下载")
        
        for url in urls {
            guard let videoURL = URL(string: url as String) else {
                print("下载地址有误 error")
                hide_m3u8_downloadStatusView()
                return
            }
            let downloadTask = m3u8_session.downloadTask(with: videoURL)
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
        
        self.backgroundUpdateTask = beginBackgroundUpdateTask()
        
        m3u8DownloadStatusView.progressLabel.text = NSLocalizedString("Processing", comment: "处理中...")
        guard let documentURL = VideoMarksConstants.documentURL() else { return }
        
        let fileManager = FileManager.default
        let combineDir = documentURL.appendingPathComponent("tmpCombine", isDirectory: true);
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var previousTime = kCMTimeZero
        
        guard let tsTask = tsFileDownloadTask else {
            print("tsFileDownloadTask is nil")
            return
        }
    
        for i in 0 ..< tsTask.totalTaskCount {
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
                    self.hide_m3u8_downloadStatusView()
                    return
                }
                
                try videoTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, end: asset.duration), of: asset.tracks(withMediaType: AVMediaTypeVideo)[0], at: previousTime)
                try audioTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, end: asset.duration), of: asset.tracks(withMediaType: AVMediaTypeAudio)[0], at: previousTime)
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
        let exportURL = documentURL.appendingPathComponent("tmp.mp4")
        if fileManager.fileExists(atPath: exportURL.path) {
            do {
                print("文件已存在 删除文件")
                try fileManager.removeItem(at: exportURL)
            } catch {
                print("删除文件失败 \(error)")
                self.hide_m3u8_downloadStatusView()
            }
        }
        
        exportor.outputURL = exportURL
        exportor.outputFileType = AVFileTypeMPEG4
        
        exportor.exportAsynchronously { 
            DispatchQueue.main.async(execute: {
                if exportor.status == .completed {
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
        
        hide_m3u8_downloadStatusView()
        
        // 把视频文件导入到相册
        saveVideoToPhotos()
    }
    
    // MARK: - 保存视频到相册
    func saveVideoToPhotos() {
        print("保存视频到相册")
        guard let documentURL = VideoMarksConstants.documentURL() else { return }
        
        let fileURL = documentURL.appendingPathComponent("tmp.mp4")

        PHPhotoLibrary.shared().performChanges({
            if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL) {
                let collectionChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection!)
                let asset = assetChangeRequest.placeholderForCreatedAsset!
                let assets = NSArray(object: asset)
                collectionChangeRequest?.addAssets(assets)
            }
        }) { (success, error) in
            guard success == true else {
                print("download Video error \(error)")
                return
            }
            
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("error delete")
            }
            
            DispatchQueue.main.async(execute: { 
                self.finishTSDownloadTask()
            })
        }
    }
    
    // MARK: - 完成下载TSFile的任务
    func finishTSDownloadTask() {
        tsFileDownloadTask = nil
        print("清楚下载任务")
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
    
    // MARK: - Asset Caching
    func resetCachedAssets()  {
        imageManager?.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }
    
    func updateCachedAssets() {
        let isVisible = self.isViewLoaded && self.view.window != nil
        
        guard isVisible else {
            return
        }
        
        var preheatRect = self.collectionView?.bounds
        let preHeight = preheatRect!.height
        
        preheatRect = preheatRect!.insetBy(dx: 0.0, dy: -0.5 * preHeight)
        
        let delta = abs(preheatRect!.midY - self.previousPreheatRect!.midY)
        if delta > self.collectionView!.bounds.height / 3.0 {
            var addedIndexPaths: [IndexPath] = []
            var removedIndexPaths: [IndexPath] = []
            self.computeDifferenceBetween(self.previousPreheatRect!, andNewRect: preheatRect!, removedHandler: { (removedRect) in
                let indexPaths = self.collectionView!.indexPathsForElementsIn(removedRect)
                removedIndexPaths.append(contentsOf: indexPaths)
                }, addedHandler: { (addedRect) in
                    let indexPaths = self.collectionView!.indexPathsForElementsIn(addedRect)
                    addedIndexPaths.append(contentsOf: indexPaths)
            })
            
            let assetsToStartCaching = self.assetsAt(addedIndexPaths)
            let assetsToStopCaching = self.assetsAt(removedIndexPaths)
            
            self.imageManager?.stopCachingImages(for: assetsToStopCaching, targetSize: AssetGirdThumbnailSize!, contentMode: .aspectFill, options: nil)
            self.imageManager?.startCachingImages(for: assetsToStartCaching, targetSize: AssetGirdThumbnailSize!, contentMode: .aspectFill, options: nil)
            
            self.previousPreheatRect  = preheatRect
        }
    }
    
    func computeDifferenceBetween(_ oldRect: CGRect, andNewRect newRect: CGRect, removedHandler: (_ removedRect: CGRect)-> Void, addedHandler: (_ addedRect: CGRect) -> Void ) {
        if oldRect.intersects(newRect) {
            let oldMaxY =  oldRect.maxY
            let oldMinY = oldRect.minY
            let newMaxY = newRect.maxY
            let newMinY = newRect.minY
            
            if (newMaxY > oldMaxY) {
                let rectToAdd = CGRect(x: newRect.origin.x, y: oldMaxY, width: newRect.size.width, height: (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            
            if (oldMinY > newMinY) {
                let rectToAdd = CGRect(x: newRect.origin.x, y: newMinY, width: newRect.size.width, height: (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            
            if (newMaxY < oldMaxY) {
                let rectToRemoved = CGRect(x: newRect.origin.x, y: newMaxY, width: newRect.size.width, height: (oldMaxY - newMaxY))
                removedHandler(rectToRemoved)
            }
            
            if (oldMinY < newMinY) {
                let rectToRemoved = CGRect(x: newRect.origin.x, y: oldMinY, width: newRect.size.width, height: (newMinY - oldMinY))
                removedHandler(rectToRemoved)
            }
        } else {
            addedHandler(newRect)
            removedHandler(oldRect)
        }
    }
    
    func assetsAt(_ indexPaths: [IndexPath]) -> [PHAsset] {
        guard indexPaths.count > 0 else { return [] }
        
        var assets: [PHAsset] = []
        indexPaths.forEach { (idx) in
            if (idx as NSIndexPath).section == 0 {
                let asset = self.assetsFetchResults![(idx as NSIndexPath).item] as! PHAsset
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
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var numberOfItems: Int
        if section == 0 {
            numberOfItems = self.assetsFetchResults?.count ?? 0
        } else {
            numberOfItems = self.taskManager.taskList.count
        }
        
        return numberOfItems
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var collectionViewCell: UICollectionViewCell
        
        if (indexPath as NSIndexPath).section == 0 {
            let asset = self.assetsFetchResults![(indexPath as NSIndexPath).item] as! PHAsset
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GirdViewCell", for: indexPath) as! GirdViewCell
            cell.representedAssetIdentifier = asset.localIdentifier
            
            self.imageManager?.requestImage(for: asset, targetSize: AssetGirdThumbnailSize!, contentMode: .aspectFill, options: nil, resultHandler: { (image, info) in
                if cell.representedAssetIdentifier == asset.localIdentifier {
                    cell.thumbnail = image
                }
            })
            
            collectionViewCell = cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DownloadViewCell", for: indexPath) as! DownloadViewCell
            
            // 设置DownloadCell...
            collectionViewCell = cell
        }
        
        // Configure the cell
    
        return collectionViewCell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).section == 0 {
            let asset = self.assetsFetchResults![(indexPath as NSIndexPath).item] as! PHAsset
            let videoRequestOptions = PHVideoRequestOptions()
            videoRequestOptions.deliveryMode = .highQualityFormat
            
            self.imageManager?.requestPlayerItem(forVideo: asset, options: videoRequestOptions, resultHandler: { (avplayerItem, info) in
                let player = AVPlayer(playerItem: avplayerItem!)
                PlayerController.sharedInstance.playVideo(player, inViewController: self)
            })
        }
    }
}

extension AssetGirdVC: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard self.assetsFetchResults != nil else { return }
        if let collectionChanges = changeInstance.changeDetails(for: self.assetsFetchResults! as! PHFetchResult<PHObject>) {
            DispatchQueue.main.async(execute: { [weak self] in
                self?.assetsFetchResults = collectionChanges.fetchResultAfterChanges as? PHFetchResult<AnyObject>
                
                if !collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves {
                    self?.collectionView?.reloadData()
                } else {
                    self?.collectionView?.performBatchUpdates({
                        if let removedIndexes = collectionChanges.removedIndexes , removedIndexes.count > 0 {
                            self?.collectionView?.deleteItems(at: removedIndexes.indexPathsFromIndexesWith(0))
                        }
                        
                        if let insertedIndexes = collectionChanges.insertedIndexes , insertedIndexes.count > 0 {
                            self?.collectionView?.insertItems(at: insertedIndexes.indexPathsFromIndexesWith(0))
                        }
                        
                        if let changedIndexes = collectionChanges.changedIndexes , changedIndexes.count > 0 {
                            self?.collectionView?.reloadItems(at: changedIndexes.indexPathsFromIndexesWith(0))
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

extension AssetGirdVC: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 完成下载
        print("完成下载 文件在\(location)")
        
        guard let tsTask = tsFileDownloadTask else {
            print("tsFileDownloadTas 为nil")
            return
        }
        
        tsTask.completeTaskCount += 1
        
        let totalSizeWrite = ByteCountFormatter.string(fromByteCount: tsTask.totalWrite, countStyle: .binary)
        DispatchQueue.main.async {
            self.m3u8DownloadStatusView.progressLabel.text = "\(tsTask.completeTaskCount)/\(tsTask.totalTaskCount) \(totalSizeWrite)"
        }
        
        print("已下载 \(tsTask.completeTaskCount) 个")
        
        if let documentURL = VideoMarksConstants.documentURL() {
            let fileManager = FileManager.default
            let combineDir = documentURL.appendingPathComponent("tmpCombine", isDirectory: true)
        
            if !fileManager.fileExists(atPath: combineDir.path) {
                do {
                    print("文件夹不存在 创建文件夹")
                    try fileManager.createDirectory(at: combineDir, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print("创建文件夹失败 \(error)")
                    
                    DispatchQueue.main.async {
                        self.hide_m3u8_downloadStatusView()
                    }
                }
            }
            
            print("combineDir is \(combineDir)")
            
            var indexVideo: Int = -1
            
            for (idx,task) in tsTask.subTasks.enumerated() {
                if task.taskIdentifier == downloadTask.taskIdentifier {
                    indexVideo = idx
                    break
                }
            }
            
            guard indexVideo != -1 else {
                print("下载任务index 出错")
                DispatchQueue.main.async {
                    self.hide_m3u8_downloadStatusView()
                }
                return
            }
            
            print("the idx is \(indexVideo)")
            let videoURL = combineDir.appendingPathComponent("\(indexVideo).mp4")
            
            if fileManager.fileExists(atPath: videoURL.path) {
                do {
                    print("删除已存在 \(videoURL) 的文件")
                    try fileManager.removeItem(at: videoURL)
                } catch {
                    print("remove item error \(error)")
                    DispatchQueue.main.async {
                        self.hide_m3u8_downloadStatusView()
                    }
                }
            }
            
            do {
                print("move item to destURL \(videoURL)")
                try fileManager.moveItem(at: location, to: videoURL)
            } catch {
                print("error download \(error)")
                DispatchQueue.main.async {
                    self.hide_m3u8_downloadStatusView()
                }
            }
        }
        
        if tsTask.completeTaskCount == tsTask.totalTaskCount {
            print("全部下载完 开始合并文件")
            DispatchQueue.main.async(execute: {
                self.combineAllVideoFragment()
            })
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // 恢复下载
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 写入
        
        guard let task = tsFileDownloadTask else {
            print("tsFileDownloadTas 为nil")
            return
        }
        
        task.totalWrite += bytesWritten
        
        let totalSizeWrite = ByteCountFormatter.string(fromByteCount: task.totalWrite, countStyle: .binary)
        
        DispatchQueue.main.async { 
            self.m3u8DownloadStatusView.progressLabel.text = "\(task.completeTaskCount)/\(task.totalTaskCount) \(totalSizeWrite)"
        }
        
    }
}

extension AssetGirdVC: URLSessionDelegate {
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
