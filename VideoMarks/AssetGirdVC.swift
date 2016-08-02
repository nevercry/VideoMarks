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

//private let reuseIdentifier = VideoMarks.GirdViewCellID
private var AssetGirdThumbnailSize: CGSize?

class AssetGirdVC: UICollectionViewController {
    var assetsFetchResults: PHFetchResult?
    var assetCollection: PHAssetCollection?
    var imageManager: PHCachingImageManager?
    var previousPreheatRect: CGRect?
    
    var taskManager = TaskManager()

    override func awakeFromNib() {
        imageManager = PHCachingImageManager()
        resetCachedAssets()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit {
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
            guard let videoUrl = alertController.textFields?.first?.text where videoUrl.isEmpty != true else { return }
            self?.taskManager.newTask(videoUrl)
            self?.collectionView?.reloadData()
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
        }
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
