//
//  VideoMarksTVC.swift
//  VideoMarks
//
//  Created by nevercry on 6/8/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import CoreData
import AVKit
import AVFoundation

struct Constant {
    static let appGroupID = "group.nevercry.videoMarks"
}

class VideoMarksTVC: UITableViewController {
    
    var dataController: DataController?
    var fetchedResultsController: NSFetchedResultsController!
    let sectionLocalizedTitles = ["",NSLocalizedString("Web", comment: "")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        self.clearsSelectionOnViewWillAppear = true
        
        self.title = NSLocalizedString("Video Marks", comment: "影签")
        self.navigationItem.rightBarButtonItem = editButtonItem()
        self.tableView.allowsSelectionDuringEditing = true
        self.tableView.estimatedRowHeight = 70
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.refreshControl?.addTarget(self, action: #selector(refreshData), forControlEvents: .ValueChanged)
        self.tableView.registerNib(UINib(nibName: "VideoMarkCell", bundle: nil), forCellReuseIdentifier: VideoMarks.VideoMarkCellID)
        
        if let _ = dataController {
            initializeFetchedResultsController()
        } else {
            fatalError("Error no dataController ")
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(refreshData), name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        // 注册CoreData完成初始化后的通知
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(updateUI), name: VideoMarks.CoreDataStackCompletion, object: nil)
        
        
        // Check for force touch feature, and add force touch/previewing capability.
        if traitCollection.forceTouchCapability == .Available {
            /*
             Register for `UIViewControllerPreviewingDelegate` to enable
             "Peek" and "Pop".
             (see: MasterViewController+UIViewControllerPreviewing.swift)
             
             The view controller will be automatically unregistered when it is
             deallocated.
             */
            registerForPreviewingWithDelegate(self, sourceView: view)
        }
    }
    
    
    func refetchResultAndUpdate() {
        do {
            try fetchedResultsController.performFetch()
            
        } catch {
            print("coredata error")
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
        tableView.reloadData()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - 更新UI
    func updateUI()  {
        refetchResultAndUpdate()
        updateVideoMarksFromExtension()
    }
    
    // MARK:- 编辑视频
    func editVideo()  {
        self.setEditing(!editing, animated: true)
    }
    
    // MARK:-  清除数据
    @IBAction func clearAllData(sender: AnyObject) {
        let altVC = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        altVC.modalPresentationStyle = .Popover
        let clearAction = UIAlertAction(title: NSLocalizedString("Clear Data", comment: "清空"), style: .Destructive) { (action) in
            self.startClearData()
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .Default, handler: nil)
        
        altVC.addAction(clearAction)
        altVC.addAction(cancelAction)
        
        if let presenter = altVC.popoverPresentationController {
            presenter.barButtonItem = sender as? UIBarButtonItem
        }
        
        presentViewController(altVC, animated: true, completion: nil)
    }
    
    func startClearData() {
        let fetchRequest = NSFetchRequest(entityName: "Video")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try dataController?.managedObjectContext.executeRequest(deleteRequest)
        } catch {
            print("delete all data error ")
        }
        
        dataController?.saveContext()
        
        refetchResultAndUpdate()
    }
    
    func refreshData() {
        updateVideoMarksFromExtension()
        self.refreshControl?.endRefreshing()
    }
    
    //MARK:- 从Group UserDefault 里提取保存的VideoMarks数据
    func updateVideoMarksFromExtension() {
        let groupDefaults = NSUserDefaults.init(suiteName: Constant.appGroupID)!
        
        if let jsonData:NSData = groupDefaults.objectForKey("savedMarks") as? NSData {
            do {
                guard let jsonArray:NSArray = try NSJSONSerialization.JSONObjectWithData(jsonData, options: .AllowFragments) as? NSArray else { return }
                
                let videoMarks = jsonArray as! [[String: String]]
                
                let batchSize = 500; //can be set 100-10000 objects depending on individual object size and available device memory
                var i = 1;
                for mark in videoMarks {
                    
                    let _ = Video.init(videoInfo: mark, context: dataController!.managedObjectContext)
                    if 0 == (i % batchSize) {
                        dataController!.saveContext()
                        dataController!.managedObjectContext.reset()
                        refetchResultAndUpdate()
                    }
                    
                    i += 1
                }

                dataController!.saveContext()
                groupDefaults.removeObjectForKey("savedMarks")
                groupDefaults.synchronize()
            } catch {
                print("获取UserDefault出错")
            }
        } else {
            tableView.reloadData()
        }
    }
    
    
    func initializeFetchedResultsController() {
        let request = NSFetchRequest(entityName: "Video")
        let createAtSort = NSSortDescriptor(key: "createAt", ascending: false)
        request.sortDescriptors = [createAtSort]
        
        let moc = self.dataController!.managedObjectContext
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
    }
    
    func configureCell(cell: VideoMarkCell, indexPath: NSIndexPath) {
        let video = fetchedResultsController.fetchedObjects![indexPath.row] as! Video
        // Populate cell from the NSManagedObject instance
        
        cell.title.text = video.title
        cell.createDate.text = video.createDateDescription(dateStyle: .ShortStyle, timeStyle: .NoStyle)
        
        let noAttdurationStr = video.durationDescription()
        let durationAttriStr = NSMutableAttributedString(string: noAttdurationStr)
        
        if let expTimeInterval = video.expireTimeInterval() {
            let expStr = video.expireAttributeDescription()
            if video.isVideoInvalid(expTimeInterval) {
                // 过期
                durationAttriStr.appendAttributedString(expStr!)
            } else {
                durationAttriStr.mutableString.appendString("        ")
                durationAttriStr.appendAttributedString(expStr!)
            }
        }
        
        cell.duration.attributedText = durationAttriStr
        
        if let imageData = video.posterImage?.data {
            let resizeImage = UIImage(data: imageData)
            cell.poster.image = UIImage.resize(resizeImage!, newSize: VideoMarks.PosterImageSize)
        } else {
            let tmpImg = UIImage.alphaSafariIcon(44, scale: Float(UIScreen.mainScreen().scale))
            cell.poster.image = UIImage.resize(tmpImg, newSize: VideoMarks.PosterImageSize)
            
            let backUpDate = video.createAt
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { [weak self] in
                var imageData: NSData?
                if video.poster.isEmpty {
                    let videoUrl = NSURL(string: video.url)!
                    imageData = self?.getPreviewImageDataForVideoAtURL(videoUrl, atInterval: 1)
                } else {
                    let posterURL = NSURL(string: video.poster)!
                    imageData = NSData(contentsOfURL: posterURL)
                }
                dispatch_async(dispatch_get_main_queue(), {[weak self] in
                    if video.createAt == backUpDate {
                        if let _ = imageData {
                            // 根据16:9 截取图片
                            let preImage = UIImage(data: imageData!)!
                            let cropImage = preImage.crop16_9()
                            let cropData = UIImageJPEGRepresentation(cropImage, 1)!
                            
                            let image = Image(data: cropData, context: (self?.dataController!.managedObjectContext)!)
                            image.fromVideo = video
                            self?.dataController?.saveContext()
                        }
                    }
                })
            }
        }
        cell.poster.contentMode = .ScaleAspectFill
    }
    
    // MARK: - Table view data source and Delegate
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var heightForRow: CGFloat
        if (indexPath.section == 0) {
            heightForRow = 44
        } else {
            heightForRow = VideoMarks.VideoMarkCellRowHeight
        }
        
        return heightForRow
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sectionLocalizedTitles.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows: Int
        if section == 0 {
            numberOfRows = 1
        } else {
            numberOfRows = fetchedResultsController.fetchedObjects?.count ?? 0
        }
        
        return numberOfRows
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionLocalizedTitles[section]
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier(VideoMarks.PhotosCellID, forIndexPath: indexPath)
            cell.textLabel?.text = NSLocalizedString("Photos Library", comment: "照片")
            cell.textLabel?.textAlignment = .Center
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier(VideoMarks.VideoMarkCellID, forIndexPath: indexPath)
            // Set up the cell
            configureCell(cell as! VideoMarkCell, indexPath: indexPath)
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            // 进入手机相册
        } else {
            let video = fetchedResultsController.fetchedObjects![indexPath.row] as! Video
            
            if !editing {
                let url = NSURL(string: video.url)
                let player = AVPlayer(URL: url!)
                PlayerController.sharedInstance.playVideo(player, inViewController: self)
            } else {
                performSegueWithIdentifier("Show Video Detail", sender: video)
            }
        }
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        var canEditForRow: Bool
        if indexPath.section == 0 {
            canEditForRow = false
        } else {
            canEditForRow = true
        }
        
        return canEditForRow
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == 0 {
            return nil
        }
            
        let deleteAction = UITableViewRowAction.init(style: UITableViewRowActionStyle.Destructive, title: NSLocalizedString("Delete", comment: "删除")) { (action, indexPath) in
            let videoMark = self.fetchedResultsController.fetchedObjects![indexPath.row] as! Video
            self.dataController?.managedObjectContext.deleteObject(videoMark)
            self.dataController?.saveContext()
        }
        
        let shareAction = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Share", comment: "分享")) { (action, indexPath) in
            let videoMark = self.fetchedResultsController.fetchedObjects![indexPath.row] as! Video
            let url = NSURL(string: videoMark.url)!
            let actVC = UIActivityViewController.init(activityItems: [url], applicationActivities: [OpenSafariActivity()])
            actVC.modalPresentationStyle = .Popover
            
            if let presenter = actVC.popoverPresentationController {
                presenter.sourceView = tableView.cellForRowAtIndexPath(indexPath)
                presenter.sourceRect = CGRectMake(tableView.bounds.width, 0, 0, 44)
            }
            
            self.presentViewController(actVC, animated: true, completion: nil)
        }
        shareAction.backgroundColor = UIColor.grayColor()
        
        let video = fetchedResultsController.fetchedObjects![indexPath.row] as! Video
        
        if let expire = video.expireTimeInterval() {
            if video.isVideoInvalid(expire) {
                return [deleteAction]
            }
        }
        
        return [deleteAction,shareAction]
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let destVC = segue.destinationViewController as? VideoDetailTVC {
            if let video = sender as? Video {
                destVC.video = video
            }
        }
    }
}

// MARK:- NSFetchedResultsControllerDelegate
extension VideoMarksTVC: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
        print("begin")
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        var fixNewIndexPath: NSIndexPath?
        var fixIndexPath: NSIndexPath?
        
        if let _ = indexPath {
            fixIndexPath = NSIndexPath(forRow: indexPath!.row, inSection: 1)
        }
        
        if let _ = newIndexPath {
            fixNewIndexPath = NSIndexPath(forRow: newIndexPath!.row, inSection: 1)
        }
        
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([fixNewIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([fixIndexPath!], withRowAnimation: .Fade)
        case .Update:
            guard let updateIndex = fixIndexPath, updateCell = self.tableView.cellForRowAtIndexPath(updateIndex) as? VideoMarkCell else { return }
            configureCell(updateCell, indexPath: updateIndex)
        case .Move:
            tableView.deleteRowsAtIndexPaths([fixIndexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([fixIndexPath!], withRowAnimation: .Fade)
        }
        
        print("change index")

    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
        print("endUpdates")
    }
}

// MARK: - 3D Touch
extension VideoMarksTVC: UIViewControllerPreviewingDelegate {
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController) {
        self.navigationController?.showViewController(viewControllerToCommit, sender: nil)
    }
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {

        guard let indexPath = tableView.indexPathForRowAtPoint(location),
            cell = tableView.cellForRowAtIndexPath(indexPath),
            video = fetchedResultsController.fetchedObjects?[indexPath.row],
            storyboard = self.storyboard else { return nil }
        
        previewingContext.sourceRect = cell.frame
        let videDetailTVC = storyboard.instantiateViewControllerWithIdentifier("VideoDetailTVC") as! VideoDetailTVC
        videDetailTVC.video = video as? Video
        
        return videDetailTVC
    }
}

// MARK: - Gen Image thumbnail
extension VideoMarksTVC {
    // MARK: - 获取视频缩略图
    func getPreviewImageDataForVideoAtURL(videoURL: NSURL, atInterval: Int) -> NSData? {
        print("Taking pic at \(atInterval) second")
        let asset = AVURLAsset(URL: videoURL)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        
        var time = asset.duration
        //If possible - take not the first frame (it could be completely black or white on camara's videos)
        let tmpTime = CMTimeMakeWithSeconds(Float64(atInterval), 100)
        time.value = min(time.value, tmpTime.value)
        
        do {
            let img = try assetImgGenerate.copyCGImageAtTime(time, actualTime: nil)
            let frameImg = UIImage(CGImage: img)
            let compressImage = frameImg.clipAndCompress(64.0/44.0, compressionQuality: 1.0)
            let newImageSize = CGSizeMake(320, 220)
            UIGraphicsBeginImageContextWithOptions(newImageSize, false, 0.0)
            compressImage.drawInRect(CGRectMake(0, 0, newImageSize.width, newImageSize.height))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return UIImageJPEGRepresentation(newImage, 1.0)
        } catch {
            /* error handling here */
            print("获取视频截图失败")
        }
        return nil
    }
}

