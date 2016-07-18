//
//  VideoDetailTVC.swift
//  VideoMarks
//
//  Created by nevercry on 6/16/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class VideoDetailTVC: UITableViewController {
    
    var video: Video?
    
    // MARK: Preview actions
    override func previewActionItems() -> [UIPreviewActionItem] {
        let openInSafariAction = UIPreviewAction(title: NSLocalizedString("Open in Safari", comment: "在Safari中打开"), style: .Default) {
            previewAction, viewController in
            
            guard let detailViewController = viewController as? VideoDetailTVC else { return }
            
            let videoUrl = NSURL(string: detailViewController.video!.url)
            
            UIApplication.sharedApplication().openURL(videoUrl!)
        }
        
        let copyVideoLinkAction = UIPreviewAction(title: NSLocalizedString("Copy Link", comment: "复制链接"), style: .Default) { (action, viewController) in
            guard let videDetailTVC = viewController as? VideoDetailTVC else { return }
            UIPasteboard.generalPasteboard().string = videDetailTVC.video?.url
        }
        
        
        return [copyVideoLinkAction,openInSafariAction,]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("Video Detail", comment: "影片信息")
        self.clearsSelectionOnViewWillAppear = false
        
        if let exp = video?.expireTimeInterval() {
            if video!.isVideoInvalid(exp) {
                self.navigationItem.rightBarButtonItem?.enabled = false
            }
        }
    }
    
   // MARK:-  分享
    @IBAction func shareAction(sender: UIBarButtonItem) {
        let url = NSURL(string: video!.url)!
        let actVC = UIActivityViewController.init(activityItems: [url], applicationActivities: [OpenSafariActivity()])
        actVC.modalPresentationStyle = .Popover
        
        if let presenter = actVC.popoverPresentationController {
            presenter.barButtonItem = sender
        }
        presentViewController(actVC, animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var numOfRow = 1
        
        if video?.source.lowercaseString != "unknow" {
            numOfRow = 2
        }
        
        return numOfRow
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell{
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("Video Detail Cell", forIndexPath: indexPath) as! VideoDetailCell
            cell.textView.attributedText = video?.attributeDescriptionForTextView()
            return cell
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("Source Link Cell", forIndexPath: indexPath)
            cell.textLabel?.text = NSLocalizedString("Source Link", comment: "源链接")
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var height: CGFloat
        
        switch indexPath.row {
        case 0:
            height = video!.heightForTableView(tableView.bounds.width - 16)
        case 1:
            height = 44
        default:
            height = 0
        }
        
        return height
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        if (indexPath.row == 1) {
            let alertC = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            alertC.modalPresentationStyle = .Popover
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .Cancel, handler: {
                _ in
                
            })
            let openSafariAction = UIAlertAction(title: NSLocalizedString("Open in Safari", comment: "在Safari中打开"), style: .Default, handler: { (action) in
                let sourceURL = NSURL(string: self.video!.source)
                UIApplication.sharedApplication().openURL(sourceURL!)
            })
            
            alertC.addAction(cancelAction)
            alertC.addAction(openSafariAction)
            
            if let presenter = alertC.popoverPresentationController {
                presenter.sourceView = tableView.cellForRowAtIndexPath(indexPath)?.textLabel
                presenter.sourceRect = CGRectMake(0, 44, 44, 0)
                presenter.permittedArrowDirections = .Up
            }
            
            presentViewController(alertC, animated: true, completion: nil)
            
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
}