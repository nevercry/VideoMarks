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
import StoreKit

class VideoMarksTVC: UITableViewController {
    
    var dataController: DataController?
    var fetchedResultsController: NSFetchedResultsController<Video>!
    var memCache = NSCache<NSString,NSString>()
    
    // MARK:  View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
        self.registerNotification()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupViews() {
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        self.clearsSelectionOnViewWillAppear = true
        self.navigationItem.title = NSLocalizedString("Video Marks", comment: "影签")
        self.navigationItem.rightBarButtonItem = editButtonItem
        self.tableView.allowsSelectionDuringEditing = true
        self.tableView.estimatedRowHeight = 70
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.refreshControl?.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        self.tableView.register(UINib(nibName: "VideoMarkCell", bundle: nil), forCellReuseIdentifier: VideoMarksConstants.VideoMarkCellID)
        if let _ = dataController {
            initializeFetchedResultsController()
        } else {
            fatalError("Error no dataController ")
        }
        // Check for force touch feature, and add force touch/previewing capability.
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
    }
    
    func registerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        // 注册CoreData完成初始化后的通知
        NotificationCenter.default.addObserver(self, selector: #selector(coreDataStackComplete), name: NSNotification.Name(rawValue: VideoMarksConstants.CoreDataStackCompletion), object: nil)
    }
    
    
    /**
     CoreStack 完成初始化
     */
    func coreDataStackComplete()  {
        refetchResultAndUpdate()
        updateVideoMarksFromExtension()
    }
    
    /**
     初始化FetchedResultsController
     */
    func initializeFetchedResultsController() {
        let request = NSFetchRequest<Video>(entityName: "Video")
        let createAtSort = NSSortDescriptor(key: "createAt", ascending: false)
        request.sortDescriptors = [createAtSort]
        
        let moc = self.dataController!.managedObjectContext
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: "VideoCache")
        fetchedResultsController.delegate = self
    }
    
    /**
     获取数据并更新
     */
    func refetchResultAndUpdate() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
        tableView.reloadData()
    }
    
    /**
     刷新数据
     */
    func refreshData() {
        updateVideoMarksFromExtension()
        self.refreshControl?.endRefreshing()
    }

    /**
     编辑视频
     */
    func editVideo()  {
        self.setEditing(!isEditing, animated: true)
    }
    
    /**
     从Group UserDefault 里提取保存的VideoMarks数据
     */
    func updateVideoMarksFromExtension() {
        let groupDefaults = UserDefaults.init(suiteName: VideoMarksConstants.appGroupID)!
        
        if let savedMarksData = groupDefaults.object(forKey: "savedMarks") as? Data {
            if let savedMarks = try! JSONSerialization.jsonObject(with: savedMarksData, options: .allowFragments) as? NSArray {
                
                let batchSize = 500; //can be set 100-10000 objects depending on individual object size and available device memory
                var i = 1;
                for mark in savedMarks {
                    let _ = Video(videoInfo: mark as! [String:String], context: dataController!.managedObjectContext)
                    if 0 == (i % batchSize) {
                        dataController!.saveContext()
                        dataController!.managedObjectContext.reset()
                        refetchResultAndUpdate()
                    }
                    i += 1
                }
                
                dataController!.saveContext()
                groupDefaults.removeObject(forKey: "savedMarks")
                groupDefaults.synchronize()
            }
        } else {
            tableView.reloadData()
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let destVC = segue.destination as? VideoDetailTVC {
            if let video = sender as? Video {
                destVC.video = video
            }
        }
    }
}

// MARK: - Table view data source and Delegate

extension VideoMarksTVC {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return VideoMarksConstants.VideoMarkCellRowHeight
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VideoMarksConstants.VideoMarkCellID, for: indexPath)
        // Set up the cell
        configureCell(cell as! VideoMarkCell, indexPath: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = fetchedResultsController.fetchedObjects![(indexPath as NSIndexPath).row] 
        if !isEditing {
            PlayerController.sharedInstance.playVideo(video.player, inViewController: self)
        } else {
            performSegue(withIdentifier: "Show Video Detail", sender: video)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction.init(style: .destructive, title: NSLocalizedString("Delete", comment: "删除")) { (action, indexPath) in
            let videoMark = self.fetchedResultsController.fetchedObjects![(indexPath as NSIndexPath).row] 
            self.dataController?.managedObjectContext.delete(videoMark)
            self.dataController?.saveContext()
        }
        
        let shareAction = UITableViewRowAction(style: .normal, title: NSLocalizedString("Share", comment: "分享")) { (action, indexPath) in
            let videoMark = self.fetchedResultsController.fetchedObjects![(indexPath as NSIndexPath).row] 
            let url = URL(string: videoMark.url)!
            let actVC = UIActivityViewController.init(activityItems: [url], applicationActivities: [OpenSafariActivity()])
            actVC.modalPresentationStyle = .popover
            if let presenter = actVC.popoverPresentationController {
                presenter.sourceView = tableView.cellForRow(at: indexPath)
                presenter.sourceRect = CGRect(x: tableView.bounds.width, y: 0, width: 0, height: 44)
            }
            self.present(actVC, animated: true, completion: nil)
        }
        shareAction.backgroundColor = UIColor.gray
        return [deleteAction,shareAction]
    }
    
    // MARK: 设置cell
    
    /**
     初始化Cell
     
     - parameter cell:      需要初始化的Cell
     - parameter indexPath: cell在tableView中的indexPath
     */
    func configureCell(_ cell: VideoMarkCell, indexPath: IndexPath) {
        let video = fetchedResultsController.fetchedObjects![(indexPath as NSIndexPath).row] 
        // Populate cell from the NSManagedObject instance
        cell.configFor(video: video)
    }
}


// MARK:- NSFetchedResultsControllerDelegate
extension VideoMarksTVC: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            guard let updateIndex = indexPath, let updateCell = self.tableView.cellForRow(at: updateIndex) as? VideoMarkCell else { return }
            configureCell(updateCell, indexPath: updateIndex)
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

// MARK: - 3D Touch
extension VideoMarksTVC: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.show(viewControllerToCommit, sender: nil)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = tableView.indexPathForRow(at: location),
            let cell = tableView.cellForRow(at: indexPath),
            let video = fetchedResultsController.fetchedObjects?[(indexPath as NSIndexPath).row],
            let storyboard = self.storyboard else { return nil }
        
        previewingContext.sourceRect = cell.frame
        let videDetailTVC = storyboard.instantiateViewController(withIdentifier: "VideoDetailTVC") as! VideoDetailTVC
        videDetailTVC.video = video        
        return videDetailTVC
    }
}
