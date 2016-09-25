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
    override var previewActionItems : [UIPreviewActionItem] {
        let openInSafariAction = UIPreviewAction(title: NSLocalizedString("Open in Safari", comment: "在Safari中打开"), style: .default) { (_, viewController) in
            guard let detailViewController = viewController as? VideoDetailTVC else { return }
            let videoUrl = URL(string: detailViewController.video!.url)
            UIApplication.shared.openURL(videoUrl!)
        }
        
        let copyVideoLinkAction = UIPreviewAction(title: NSLocalizedString("Copy Link", comment: "复制链接"), style: .default) { (_, viewController) in
            guard let videDetailTVC = viewController as? VideoDetailTVC else { return }
            UIPasteboard.general.string = videDetailTVC.video?.url
        }
        
        return [copyVideoLinkAction,openInSafariAction,]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("Video Detail", comment: "影片信息")
        self.clearsSelectionOnViewWillAppear = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.backBarButtonItem?.title = "返回"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
   // MARK:-  分享
    @IBAction func shareAction(_ sender: UIBarButtonItem) {
        let url = URL(string: video!.url)!
        let actVC = UIActivityViewController.init(activityItems: [url], applicationActivities: [OpenSafariActivity()])
        actVC.modalPresentationStyle = .popover
        
        if let presenter = actVC.popoverPresentationController {
            presenter.barButtonItem = sender
        }
        present(actVC, animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numOfRow = 1
        if video?.source.lowercased() != "unknow" {
            numOfRow = 2
        }
        return numOfRow
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        if (indexPath as NSIndexPath).row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Video Detail Cell", for: indexPath) as! VideoDetailCell
            cell.textView.attributedText = video?.attributeDescriptionForTextView()
            return cell
        } else if (indexPath as NSIndexPath).row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Source Link Cell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString("Source Link", comment: "源链接")
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat
        switch (indexPath as NSIndexPath).row {
        case 0:
            height = video!.heightForTableView(tableView.bounds.width - 16)
        case 1:
            height = 44
        default:
            height = 0
        }
        
        return height
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if ((indexPath as NSIndexPath).row == 1) {
            let alertC = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alertC.modalPresentationStyle = .popover
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .cancel, handler: {
                _ in
                
            })
            let openSafariAction = UIAlertAction(title: NSLocalizedString("Open in Safari", comment: "在Safari中打开"), style: .default, handler: { (action) in
                let sourceURL = URL(string: self.video!.source)
                UIApplication.shared.openURL(sourceURL!)
            })
            
            alertC.addAction(cancelAction)
            alertC.addAction(openSafariAction)
            
            if let presenter = alertC.popoverPresentationController {
                presenter.sourceView = tableView.cellForRow(at: indexPath)?.textLabel
                presenter.sourceRect = CGRect(x: 0, y: 44, width: 44, height: 0)
                presenter.permittedArrowDirections = .up
            }
            
            present(alertC, animated: true, completion: nil)
            
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
}
