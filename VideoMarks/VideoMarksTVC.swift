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
import GoogleMobileAds
import StoreKit

struct Constant {
    static let appGroupID = "group.nevercry.videoMarks"
}

class VideoMarksTVC: UITableViewController {
    
    var bannerView: GADBannerView?
    var removeAdButton: UIButton?

    var dataController: DataController?
    var fetchedResultsController: NSFetchedResultsController!
    
    var iAPRequest: SKProductsRequest?
    
    var memCache = NSCache()
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Product 有效 显示广告
        addGoogleAd()
        
        // 验证productID 是否有效
        validateProductIdentifier()
        
        // 验证receipt
        verifyReceipt()
        
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
    
    // MARK: - Update Unwind
    @IBAction func unwindToVideoMarksTVC(segue: UIStoryboardSegue) {
        verifyReceipt()
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
    
    // MARK: - 更新数据
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
        cell.configFor(video: video)
    }
    
    // MARK: - Table view data source and Delegate
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var heightForRow: CGFloat
        
        heightForRow = VideoMarks.VideoMarkCellRowHeight
        
        return heightForRow
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows: Int
        
        numberOfRows = fetchedResultsController.fetchedObjects?.count ?? 0
        
        return numberOfRows
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        cell = tableView.dequeueReusableCellWithIdentifier(VideoMarks.VideoMarkCellID, forIndexPath: indexPath)
        // Set up the cell
        configureCell(cell as! VideoMarkCell, indexPath: indexPath)
        
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let video = fetchedResultsController.fetchedObjects![indexPath.row] as! Video
        
        if !editing {
            PlayerController.sharedInstance.playVideo(video.player, inViewController: self)
        } else {
            performSegueWithIdentifier("Show Video Detail", sender: video)
        }
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        
        return true
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
       
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

extension VideoMarksTVC {
    // MARK: - 解除广告
    func removeGoogleAd() {
        removeAdButton?.removeFromSuperview()
        removeAdButton?.removeTarget(self, action: #selector(showInAppPurchase), forControlEvents: .TouchUpInside)
        removeAdButton = nil
        bannerView?.removeFromSuperview()
        bannerView = nil
    }
    
    // MARK: - 加载广告
    func addGoogleAd() {
        // 加载广告
        bannerView = GADBannerView()
        
        self.navigationController?.view.addSubview(bannerView!)
        bannerView!.translatesAutoresizingMaskIntoConstraints = false
        // 添加约束
        let constraintBottom = NSLayoutConstraint(item: bannerView!, attribute: .Bottom, relatedBy: .Equal, toItem: self.navigationController?.view, attribute: .Bottom, multiplier: 1, constant: 0)
        let constraintCenterH = NSLayoutConstraint(item: bannerView!, attribute: .CenterX, relatedBy: .Equal, toItem: self.navigationController?.view, attribute: .CenterX, multiplier: 1, constant: 0)
        
        let constraintHeight = NSLayoutConstraint(item: bannerView!, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 50)
        let constraintWidth = NSLayoutConstraint(item: bannerView!, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 320)
        
        NSLayoutConstraint.activateConstraints([constraintBottom,constraintCenterH,constraintHeight,constraintWidth])
        
        //print("Google Mobile Ads SDK version: \(GADRequest.sdkVersion())")
        // TestAd
        // bannerView!.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        
        // Production Ad
        bannerView!.adUnitID = "ca-app-pub-5747346530004992/2632216067"
        bannerView!.rootViewController = self
        bannerView!.loadRequest(GADRequest())
        
        // 用户能否去广告
        // 加载去广告按钮
        removeAdButton = UIButton(type: .Custom)
        removeAdButton?.backgroundColor = UIColor.clearColor()
        bannerView?.addSubview(removeAdButton!)
        removeAdButton!.translatesAutoresizingMaskIntoConstraints = false
        // 添加约束
        let buttonConstraintWidth = NSLayoutConstraint(item: removeAdButton!, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 50)
        let buttonConstraintHeight = NSLayoutConstraint(item: removeAdButton!, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 50)
        let buttonC_CenterY = NSLayoutConstraint(item: removeAdButton!, attribute: .CenterY, relatedBy: .Equal, toItem: bannerView!, attribute: .CenterY, multiplier: 1, constant: 0)
        let buttonC_Trailing = NSLayoutConstraint(item: removeAdButton!, attribute: .Trailing, relatedBy: .Equal, toItem: bannerView!, attribute: .Trailing, multiplier: 1, constant: 0)
        
        NSLayoutConstraint.activateConstraints([buttonConstraintWidth, buttonConstraintHeight, buttonC_CenterY, buttonC_Trailing])
        
        removeAdButton?.setImage(UIImage(named: "ad_close"), forState: .Normal)
        removeAdButton?.imageEdgeInsets = UIEdgeInsets(top: -26, left: 0, bottom: 0, right: -26)
        removeAdButton?.addTarget(self, action: #selector(showInAppPurchase), forControlEvents: .TouchUpInside)
    }
    
    // MARK: - 显示In App Purchase
    func showInAppPurchase() {
        print("show In App Purchase")
        
        self.performSegueWithIdentifier("showRemoveAdSegue", sender: nil)
    }
    
    // MARK: - 验证ProductID
    func validateProductIdentifier() {
        if let url = NSBundle.mainBundle().URLForResource("product_ids", withExtension: "plist") {
            if let productIds = NSArray(contentsOfURL: url) as? [String] {
                iAPRequest = SKProductsRequest(productIdentifiers: Set(productIds))
                iAPRequest?.delegate = self
                iAPRequest?.start()
            }
        }
    }
    
    // MARK: - 验证Receipt
    func verifyReceipt(){
        //Load in the receipt
        let receiptUrl = NSBundle.mainBundle().appStoreReceiptURL
        
        //Check if it's actually there
        guard NSFileManager.defaultManager().fileExistsAtPath(receiptUrl!.path!) else { return }
        
        let receipt: NSData = try! NSData(contentsOfURL:receiptUrl!, options: [])
        let receiptBio = BIO_new(BIO_s_mem())
        BIO_write(receiptBio, receipt.bytes, Int32(receipt.length))
        let receiptPKCS7 = d2i_PKCS7_bio(receiptBio, nil)
        //Verify receiptPKCS7 is not nil
        
        //Read in Apple's Root CA
        let appleRoot = NSBundle.mainBundle().URLForResource("AppleIncRootCertificate", withExtension: "cer")
        let caData = NSData(contentsOfURL: appleRoot!)
        let caBIO = BIO_new(BIO_s_mem())
        BIO_write(caBIO, caData!.bytes, Int32(caData!.length))
        let caRootX509 = d2i_X509_bio(caBIO, nil)
        BIO_vfree(caBIO)
        
        //Verify the receipt was signed by Apple
        let caStore = X509_STORE_new()
        X509_STORE_add_cert(caStore, caRootX509)
        X509_free(caRootX509)
        
        OpenSSL_add_all_digests()
        let verifyResult = PKCS7_verify(receiptPKCS7, nil, caStore, nil, nil, 0)
        
        if verifyResult != 1 {
            print("Validation Fails!")
            return
        }
        
        X509_STORE_free(caStore)
        
        let octets = pkcs7_d_data(pkcs7_d_sign(receiptPKCS7).memory.contents)
        
        var ptr = UnsafePointer<UInt8>(octets.memory.data)
        let end = ptr.advancedBy(Int(octets.memory.length))
        var type: Int32 = 0
        var xclass: Int32 = 0
        var length = 0
        
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr)
        if (type != V_ASN1_SET) {
            print("failed to read ASN1 from receipt")
            return
        }
        
        var bundleIdString1: NSString?
        var bundleVersionString1: NSString?
        var bundleIdData1: NSData?
        var hashData1: NSData?
        var opaqueData1: NSData?
        // Original Application Version
        var originalAppVersion: NSString?
        // ProductID
        var productID: NSString?
        
        while (ptr < end)
        {
            var integer: UnsafeMutablePointer<ASN1_INTEGER>
            
            // Expecting an attribute sequence
            ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr)
            if type != V_ASN1_SEQUENCE {
                print("ASN1 error: expected an attribute sequence")
                return
            }
            
            let seq_end = ptr.advancedBy(length)
            var attr_type = 0
            
            // The attribute is an integer
            ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr)
            if type != V_ASN1_INTEGER {
                print("ASN1 error: attribute not an integer")
                return
            }
            
            integer = c2i_ASN1_INTEGER(nil, &ptr, length)
            attr_type = ASN1_INTEGER_get(integer)
            ASN1_INTEGER_free(integer)
            
            // The version is an integer
            ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr)
            if type != V_ASN1_INTEGER {
                print("ASN1 error: version not an integer")
                return
            }
            
            integer = c2i_ASN1_INTEGER(nil, &ptr, length);
            ASN1_INTEGER_free(integer);
            
            // The attribute value is an octet string
            ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr)
            if type != V_ASN1_OCTET_STRING {
                print("ASN1 error: value not an octet string")
                return
            }
            
            if attr_type == 2 {
                // Bundle identifier
                var str_ptr = ptr
                var str_type: Int32 = 0
                var str_length = 0
                var str_xclass: Int32 = 0
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr)
                if str_type == V_ASN1_UTF8STRING {
                    bundleIdString1 = NSString(bytes: str_ptr, length: str_length, encoding: NSUTF8StringEncoding)
                    bundleIdData1 = NSData(bytes: ptr, length: length)
                }
            }
            else if attr_type == 3 {
                // Bundle version
                var str_ptr = ptr
                var str_type: Int32 = 0
                var str_length = 0
                var str_xclass: Int32 = 0
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr)
                
                if str_type == V_ASN1_UTF8STRING {
                    bundleVersionString1 = NSString(bytes: str_ptr, length: str_length, encoding: NSUTF8StringEncoding)
                }
            }
            else if attr_type == 4 {
                // Opaque value
                opaqueData1 = NSData(bytes: ptr, length: length)
            }
            else if attr_type == 5 {
                // Computed GUID (SHA-1 Hash)
                hashData1 = NSData(bytes: ptr, length: length)
            } else if attr_type == 17 {
                //In app receipt
                let r = NSData(bytes: ptr, length: length)
                let id = self.getProductIdFromReceipt(r)
                
                if id != nil {
                    productID = id
                }
            } else if attr_type == 19{
                // Original Application Version
                var str_ptr = ptr
                var str_type: Int32 = 0
                var str_length = 0
                var str_xclass: Int32 = 0
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr)
                
                if str_type == V_ASN1_UTF8STRING {
                    originalAppVersion = NSString(bytes: str_ptr, length: str_length, encoding: NSUTF8StringEncoding)
                }
            }
            
            // Move past the value
            ptr = ptr.advancedBy(length)
        }
        
        //Make sure that expected values from the receipt are actually there
        if bundleIdString1 == nil {
            print("No Bundle Id Found")
            return
        }
        if bundleVersionString1 == nil {
            print("No Bundle Version String Found")
            return
        }
        if opaqueData1 == nil {
            print("No Opaque Data Found")
            return
        }
        if hashData1 == nil {
            print("No Hash Value Found")
            return
        }
        if originalAppVersion == nil {
            print("No originalAppVersion")
            return
        }
        
        //Verify the bundle id in the receipt matches the app, use hard coded value instead of pulling
        //info.plist since the plist can be changed by anyone that knows anything
        if bundleIdString1 != "com.nevercry.VideoMarks" {
            print("Receipt verification error: Wrong bundle identifier")
            return
        }
        
        // Retrieve the Device GUID
        let device = UIDevice.currentDevice()
        let uuid = device.identifierForVendor
        let mutableData = NSMutableData(length: 16)
        uuid!.getUUIDBytes(UnsafeMutablePointer(mutableData!.mutableBytes))
        
        // Verify the hash
        var hash = Array<UInt8>(count: 20, repeatedValue: 0)
        var ctx = SHA_CTX()
        SHA1_Init(&ctx)
        SHA1_Update(&ctx, mutableData!.bytes, mutableData!.length)
        SHA1_Update(&ctx, opaqueData1!.bytes, opaqueData1!.length)
        SHA1_Update(&ctx, bundleIdData1!.bytes, bundleIdData1!.length)
        SHA1_Final(&hash, &ctx)
        
        let computedHashData1 = NSData(bytes: &hash, length: 20)
        if !computedHashData1.isEqualToData(hashData1!)
        {
            print("Receipt Hash Did Not Match!")
            return
        }
        
        print("the app origianl Version is \(originalAppVersion)")
        
        if originalAppVersion!.compare("1.3", options: .NumericSearch) == .OrderedDescending {
            // original bigger than 1.3， 1.3之后的用户 需要验证IAP购买解除广告
            //print("验证IAP")
            if productID == VideoMarksProducts.RemoveAd {
                //print("解除广告")
                removeGoogleAd()
            }
        } else {
            // original lower than 1.3 1.3前的版本 默认是购买过的用户
            print("解除广告 original lower than 1.3 ")
            removeGoogleAd()
        }
        
        defer {
            BIO_vfree(receiptBio)
            PKCS7_free(receiptPKCS7)
        }
    }
    
    func getProductIdFromReceipt(data:NSData) -> String?
    {
        var p = UnsafePointer<UInt8>(data.bytes)
        let dataLength = data.length
        
        var type:Int32 = 0
        var tag:Int32 = 0
        var length = 0
        let end = p + dataLength
        
        ASN1_get_object(&p, &length, &type, &tag, end - p)
        if type != V_ASN1_SET {
            return nil
        }
        var integer: UnsafeMutablePointer<ASN1_INTEGER>
        
        while p < end
        {
            // Expecting an attribute sequence
            ASN1_get_object(&p, &length, &type, &tag, end - p)
            if type != V_ASN1_SEQUENCE {
                print("ASN1 error: expected an attribute sequence")
            }
            
            var attr_type = 0
            
            // The attribute is an integer
            ASN1_get_object(&p, &length, &type, &tag, end - p)
            if type != V_ASN1_INTEGER {
                print("ASN1 error: attribute not an integer")
                return nil
            }
            integer = c2i_ASN1_INTEGER(nil, &p, length)
            attr_type = ASN1_INTEGER_get(integer)
            ASN1_INTEGER_free(integer)
            
            // The version is an integer
            ASN1_get_object(&p, &length, &type, &tag, end - p)
            if type != V_ASN1_INTEGER {
                print("ASN1 error: version not an integer")
                return nil
            }
            integer = c2i_ASN1_INTEGER(nil, &p, length);
            ASN1_INTEGER_free(integer);
            
            // The attribute value is an octet string
            ASN1_get_object(&p, &length, &type, &tag, end - p)
            if type != V_ASN1_OCTET_STRING {
                print("ASN1 error: value not an octet string")
                return nil
            }
            
            //For Product Id
            if attr_type == 1702
            {
                if type == V_ASN1_OCTET_STRING
                {
                    ASN1_get_object(&p, &length, &type, &tag, end - p)
                    let productId = NSString(bytes: p, length: length, encoding: NSUTF8StringEncoding)
                    return productId as? String
                }
            }
            
            p = p.advancedBy(length)
        }
        return nil
    }
}

// MARK: -
extension VideoMarksTVC: SKProductsRequestDelegate {
    func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        guard let product = response.products.last else {
            removeGoogleAd()
            return
        }
        
        for invaidId in response.invalidProductIdentifiers {
            if invaidId == product.productIdentifier {
                removeGoogleAd()
                return
            }
        }
    }
}
