//
//  PhotosTVC.swift
//  VideoMarks
//
//  Created by nevercry on 7/13/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import Photos

class PhotosTVC: UITableViewController {
    var sectionFetchResults:[AnyObject]?
    let sectionLocalizedTitles = ["",NSLocalizedString("Albums", comment: "")]
    var isPhotosCanAccess: Bool = false {
        didSet {
            tableView.tableFooterView?.hidden = isPhotosCanAccess
            navigationItem.rightBarButtonItem?.enabled = isPhotosCanAccess
        }
    }
   
    override func awakeFromNib() {
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
        
        let allVideosOptions = PHFetchOptions()
        allVideosOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.Video.rawValue)
        allVideosOptions.includeHiddenAssets = true
        allVideosOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate",ascending: true)]
        let allVideos = PHAsset.fetchAssetsWithOptions(allVideosOptions)
        
        let topLevelUserCollections = PHCollectionList.fetchTopLevelUserCollectionsWithOptions(nil)
        
        self.sectionFetchResults = [allVideos,topLevelUserCollections]
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Photos"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(addNewAlbum))
        
        let status = PHPhotoLibrary.authorizationStatus()

        switch status {
        case .Authorized:
            isPhotosCanAccess = true
        default:
            isPhotosCanAccess = false
        }
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Actions
    func addNewAlbum(sender: UIBarButtonItem) {
        // 添加新的相册
        let alertC = UIAlertController(title: NSLocalizedString("New Ablum", comment: "新建相册"), message: nil, preferredStyle: .Alert)
        alertC.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = NSLocalizedString("Ablum Name", comment: "相册名")
        }
        
        alertC.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .Cancel, handler: nil))
        alertC.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: "创建"), style: .Default) { (action) in
            let textField = alertC.textFields?.first
            guard let title = textField?.text where !title.isEmpty else { return }
            
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(title)
                }, completionHandler: { (success, error) in
                    if !success {
                        print("error create ablum: \(error)")
                    }
            })
            })
        presentViewController(alertC, animated: true, completion: nil)
    }
    
    @IBAction func goToSetting(sender: UIButton) {
        UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return sectionLocalizedTitles.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numOfRows: Int
        
        if section == 0 {
            numOfRows = isPhotosCanAccess ? 1 : 0
        } else {
            let results = sectionFetchResults![section] as! PHFetchResult
            numOfRows = results.count
        }
        
        return numOfRows
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier(VideoMarks.AllVideoCell, forIndexPath: indexPath)
            cell.textLabel?.text = NSLocalizedString("All Videos", comment: "")
        } else {
            let resut = sectionFetchResults![indexPath.section] as! PHFetchResult
            let collection = resut[indexPath.row] as! PHCollection
            
            cell = tableView.dequeueReusableCellWithIdentifier(VideoMarks.CollectionCell, forIndexPath: indexPath)
            cell.textLabel?.text = collection.localizedTitle
        }

        // Configure the cell...
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionLocalizedTitles[section]
    }
    
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        var canEditOrNot = false
        
        if indexPath.section == 0 {
            canEditOrNot = false
        } else {
            canEditOrNot = true
        }
        
        return canEditOrNot
    }
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard editingStyle == .Delete && indexPath.section == 1 else { return }
        
        let resut = sectionFetchResults![indexPath.section] as! PHFetchResult
        let collection = resut[indexPath.row] as! PHCollection
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            PHAssetCollectionChangeRequest.deleteAssetCollections([collection])
        }) { (success, error) in
            if !success {
                print("error delete ablum: \(error)")
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        guard let assetGirdVC = segue.destinationViewController as? AssetGirdVC,cell = sender as? UITableViewCell else { return }
        
        assetGirdVC.title = cell.textLabel?.text
        
        let indexPath = self.tableView.indexPathForCell(cell)
        let fetchResult = self.sectionFetchResults![indexPath!.section] as! PHFetchResult
        
        if (segue.identifier == VideoMarks.ShowAllVideos) {
            assetGirdVC.assetsFetchResults = fetchResult
        } else if (segue.identifier == VideoMarks.ShowColleciton) {
            guard let collection = fetchResult[indexPath!.row] as? PHAssetCollection else { return }
            let allVideosOptions = PHFetchOptions()
            allVideosOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.Video.rawValue)
            allVideosOptions.includeHiddenAssets = true
            allVideosOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate",ascending: true)]
            let assetFetchResult = PHAsset.fetchAssetsInAssetCollection(collection, options: allVideosOptions)
             assetGirdVC.assetsFetchResults = assetFetchResult
            assetGirdVC.assetCollection = collection
        }
    }
}

extension PhotosTVC: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            var reloadRequired = false
            self?.sectionFetchResults =  self?.sectionFetchResults?.map({ (result) -> PHFetchResult in
                let fetchResult = result as! PHFetchResult
                if let changeDetail = changeInstance.changeDetailsForFetchResult(fetchResult) {
                    reloadRequired = true
                    return changeDetail.fetchResultAfterChanges
                } else {
                    return result as! PHFetchResult
                }
            })
            
            if (reloadRequired) {
                self?.isPhotosCanAccess = true
                self?.tableView.reloadData()
            }
        }
    }
}
