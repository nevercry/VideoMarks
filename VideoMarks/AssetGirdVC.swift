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

    override func awakeFromNib() {
        imageManager = PHCachingImageManager()
        resetCachedAssets()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let scale = UIScreen.mainScreen().scale
        let flowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        let cellSize = flowLayout.itemSize
        
        AssetGirdThumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale )
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updateCachedAssets()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            let asset = self.assetsFetchResults![idx.item] as! PHAsset
            assets.append(asset)
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
        return 1
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assetsFetchResults?.count ?? 0
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let asset = self.assetsFetchResults![indexPath.item] as! PHAsset
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("GirdViewCell", forIndexPath: indexPath) as! GirdViewCell
        cell.representedAssetIdentifier = asset.localIdentifier
        
        self.imageManager?.requestImageForAsset(asset, targetSize: AssetGirdThumbnailSize!, contentMode: .AspectFill, options: nil, resultHandler: { (image, info) in
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.thumbnail = image
            }
        })
    
        // Configure the cell
    
        return cell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let asset = self.assetsFetchResults![indexPath.item] as! PHAsset
        let videoRequestOptions = PHVideoRequestOptions()
        videoRequestOptions.deliveryMode = .HighQualityFormat
        
        
        self.imageManager?.requestPlayerItemForVideo(asset, options: videoRequestOptions, resultHandler: { (avplayerItem, info) in
            let player = AVPlayer(playerItem: avplayerItem!)
            PlayerController.sharedInstance.playVideo(player, inViewController: self)
        })
        
    }

}

extension AssetGirdVC: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(changeInstance: PHChange) {
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
