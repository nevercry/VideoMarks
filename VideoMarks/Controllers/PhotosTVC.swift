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
            tableView.tableFooterView?.isHidden = isPhotosCanAccess
            navigationItem.rightBarButtonItem?.isEnabled = isPhotosCanAccess
        }
    }
   
    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = NSLocalizedString("Videos", comment: "视频")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewAlbum))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "ic_settings"), style: .plain, target: self, action: #selector(setting))
        self.clearsSelectionOnViewWillAppear = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        /* When the table view is about to appear the first time it’s loaded, the table-view controller reloads the table view’s data.  https://developer.apple.com/library/ios/documentation/UIKit/Reference/UITableViewController_Class/
        */
        if self.sectionFetchResults == nil {
            // 在界面显示时弹提示
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                isPhotosCanAccess = true
            default:
                isPhotosCanAccess = false
            }
            
            PHPhotoLibrary.shared().register(self)
            let allVideosOptions = PHFetchOptions()
            allVideosOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            allVideosOptions.includeHiddenAssets = true
            allVideosOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate",ascending: true)]
            let allVideos = PHAsset.fetchAssets(with: allVideosOptions)
            let topLevelUserCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            self.sectionFetchResults = [allVideos,topLevelUserCollections]
        }        
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func setting() {
        self.performSegue(withIdentifier: VideoMarksConstants.ShowSetting, sender: nil)
    }
    
    // MARK: Memery Warning
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Actions
    func addNewAlbum(_ sender: UIBarButtonItem) {
        // 添加新的相册
        let alertC = UIAlertController(title: NSLocalizedString("New Ablum", comment: "新建相册"), message: nil, preferredStyle: .alert)
        alertC.addTextField { (textField) in
            textField.placeholder = NSLocalizedString("Ablum Name", comment: "相册名")
        }
        
        alertC.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .cancel, handler: nil))
        alertC.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: "创建"), style: .default) { (action) in
            let textField = alertC.textFields?.first
            guard let title = textField?.text , !title.isEmpty else { return }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                }, completionHandler: { (success, error) in
                    if !success {
                        print("error create ablum: \(error)")
                    }
            })
        })
        present(alertC, animated: true, completion: nil)
    }
    
    @IBAction func goToSetting(_ sender: UIButton) {
        UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        guard let assetGirdVC = segue.destination as? AssetGirdVC,let cell = sender as? UITableViewCell else { return }
        
        assetGirdVC.title = cell.textLabel?.text
        
        let indexPath = self.tableView.indexPath(for: cell)!
        let fetchResult = self.sectionFetchResults![indexPath.section]
        
        if (segue.identifier == VideoMarksConstants.ShowAllVideos) {
            assetGirdVC.assetsFetchResults = fetchResult as? PHFetchResult<AnyObject>
        } else if (segue.identifier == VideoMarksConstants.ShowColleciton) {
            let collection = fetchResult[indexPath.row] as PHAssetCollection
            
            let allVideosOptions = PHFetchOptions()
            allVideosOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.video.rawValue)
            allVideosOptions.includeHiddenAssets = true
            allVideosOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate",ascending: true)]
            let assetFetchResult = PHAsset.fetchAssets(in: collection , options: allVideosOptions)
            assetGirdVC.assetsFetchResults = assetFetchResult as? PHFetchResult<AnyObject>
            assetGirdVC.assetCollection = collection
        }
    }
}

// MARK: - Table view data source
extension PhotosTVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionLocalizedTitles.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numOfRows: Int
        
        if section == 0 {
            numOfRows = isPhotosCanAccess ? 1 : 0
        } else {
            let results = sectionFetchResults![section]
            numOfRows = results.count
        }
        
        return numOfRows
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        if (indexPath as NSIndexPath).section == 0 {
            cell = tableView.dequeueReusableCell(withIdentifier: VideoMarksConstants.AllVideoCell, for: indexPath)
            cell.textLabel?.text = NSLocalizedString("All Videos", comment: "")
        } else {
            let resut = sectionFetchResults![indexPath.section] 
            let collection = resut[indexPath.row] as PHCollection
            cell = tableView.dequeueReusableCell(withIdentifier: VideoMarksConstants.CollectionCell, for: indexPath)
            cell.textLabel?.text = collection.localizedTitle
        }
        
        // Configure the cell...
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionLocalizedTitles[section]
    }
    
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        var canEditOrNot = false
        
        if (indexPath as NSIndexPath).section == 0 {
            canEditOrNot = false
        } else {
            canEditOrNot = true
        }
        
        return canEditOrNot
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete && (indexPath as NSIndexPath).section == 1 else { return }
        
        let resut = sectionFetchResults![indexPath.section]
        let collection = resut[indexPath.row] as PHCollection
        let assets = NSArray(object: collection)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.deleteAssetCollections(assets)
        }) { (success, error) in
            if !success {
                print("error delete ablum: \(error)")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension PhotosTVC: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            var reloadRequired = false
            self?.sectionFetchResults =  self?.sectionFetchResults?.map({ (result) -> PHFetchResult<AnyObject> in
                let fetchResult = result 
                if let changeDetail = changeInstance.changeDetails(for: fetchResult as! PHFetchResult<PHObject>) {
                    reloadRequired = true
                    return changeDetail.fetchResultAfterChanges as! PHFetchResult<AnyObject>
                } else {
                    return result as! PHFetchResult
                }
            }) as [AnyObject]?
            
            if (reloadRequired) {
                self?.isPhotosCanAccess = true
                self?.tableView.reloadData()
            }
        }
    }
}
