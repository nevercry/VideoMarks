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
    var longTapGuesture: UILongPressGestureRecognizer?
    
    deinit {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupAssetGirdThumbnailSize()
        self.setupController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 注册通知
        PHPhotoLibrary.shared().register(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 注销通知
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateCollectionViewLayout(with: size)
    }
    
    private func updateCollectionViewLayout(with size: CGSize) {
        if let layout = self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            let itemLength = size.width / 4
            layout.itemSize = CGSize(width: itemLength, height: itemLength)
            layout.invalidateLayout()
        }
    }
    
    func setupAssetGirdThumbnailSize() {
        let scale = UIScreen.main.scale
        // 设备最小尺寸来显示Cell 考虑横屏时的情况
        let minWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let itemWidth = minWidth / 4
        AssetGirdThumbnailSize = CGSize(width: itemWidth * scale, height: itemWidth * scale)
    }
    
    func setupController() {
        imageManager = PHCachingImageManager()
        resetCachedAssets()
        self.updateCachedAssets()
        self.longTapGuesture = UILongPressGestureRecognizer(target: self, action: #selector(userLongPressed(sender:)))
        self.collectionView?.addGestureRecognizer(self.longTapGuesture!)
        let flowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        let itemLength = UIScreen.main.bounds.width / 4
        flowLayout.itemSize = CGSize(width: itemLength, height: itemLength)
    }
    
    // MARK: - Actions
    func userLongPressed(sender: UILongPressGestureRecognizer) {
        let pressedLocation = sender.location(in: self.collectionView)
        if let pressedItemIndexPath = self.collectionView?.indexPathForItem(at: pressedLocation) {
            if let asset = self.assetsFetchResults?[pressedItemIndexPath.item] as? PHAsset {
                if let pressedView = self.collectionView?.cellForItem(at: pressedItemIndexPath) as? GirdViewCell {
                    showDeleteVideoActionSheet(atView: pressedView, deleteVideo: asset)
                }
            }
        }
    }
    
    func deleteVideo(video: PHAsset) {
        // Delete asset from library
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([video] as NSArray)
            }, completionHandler: nil)
    }
    
    func showDeleteVideoActionSheet(atView view: UIView, deleteVideo video: PHAsset) {
        let alertController = UIAlertController(title: nil, message: NSLocalizedString("Delete Video?", comment: "删除视频？"), preferredStyle: .actionSheet)
        alertController.modalPresentationStyle = .popover
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = view
            presenter.sourceRect = view.bounds
            presenter.permittedArrowDirections = .any
            presenter.canOverlapSourceViewRect = true
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "删除"), style: .destructive, handler: { (_) in
            self.deleteVideo(video: video)
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .cancel, handler: nil))
        
        if self.presentedViewController == nil {
            present(alertController, animated: true, completion: nil)
        }
    }
}


// MARK: - UICollectionViewDataSource and Delegate
extension AssetGirdVC {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assetsFetchResults?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let asset = self.assetsFetchResults![indexPath.item] as! PHAsset
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GirdViewCell", for: indexPath) as! GirdViewCell
        cell.representedAssetIdentifier = asset.localIdentifier
        self.imageManager?.requestImage(for: asset, targetSize: AssetGirdThumbnailSize!, contentMode: .aspectFill, options: nil, resultHandler: { (image, info) in
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.thumbnail = image
            }
        })
        
        
        return cell
    }
    
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
                        
                        }, completion:{ success in
                            if success {
                                self?.collectionView?.reloadData()
                            }
                    })
                }
                self?.resetCachedAssets()
            })
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
