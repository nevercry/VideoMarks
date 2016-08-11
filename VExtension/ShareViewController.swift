//
//  ShareViewController.swift
//  VExtension
//
//  Created by nevercry on 6/5/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import MobileCoreServices

struct Constant {
    static let appGroupID = "group.nevercry.videoMarks"
}


class ShareViewController: UIViewController {
    
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var activityStatusView: UIActivityIndicatorView!
    @IBOutlet weak var LinkLabel: UILabel!
    @IBOutlet weak var saveLinkButton: UIBarButtonItem!
    
    var userAction: ShareActions = .Save
    
    enum ShareActions: Int {
        case Save,Copy
    }
    
    var videoInfo: [String: String] = [:]  // Keys: "url","type","poster","duration","title"，“source”
    
    // MARK: 显示没有URL的警告
    func showNoURLAlert() {
        let alertTitle = NSLocalizedString("Can't fetch video link", comment: "无法获取到视频地址")
        let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: { (action) in
            self.hideExtensionWithCompletionHandler()
            
        })
        showAlert(alertTitle, message: nil, actions: [cancelAction])
    }
    
    // MARK: 显示警告
    func showAlert(title:String?, message: String?, actions: [UIAlertAction])  {
        let alC = UIAlertController.init(title: title, message: message, preferredStyle: .Alert)
        for (_,action) in actions.enumerate() {
            alC.addAction(action)
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.presentViewController(alC, animated: true, completion: nil)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.transform = CGAffineTransformMakeTranslation(0, self.view.frame.size.height)
        UIView.animateWithDuration(0.25, animations: { () -> Void in
            self.view.transform = CGAffineTransformIdentity
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        activityStatusView.stopAnimating()
        
        let propertyList = String(kUTTypePropertyList)
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
            itemProvider = item.attachments?.first as? NSItemProvider where itemProvider.hasItemConformingToTypeIdentifier(propertyList) else { return }
        
        itemProvider.loadItemForTypeIdentifier(propertyList, options: nil, completionHandler: { (diction, error) in
            guard let shareDic = diction as? NSDictionary,
            results = shareDic.objectForKey(NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary,
            vInfo = results.objectForKey("videoInfo") as? NSDictionary else { return }
            // 视频信息
            self.videoInfo["title"] = vInfo["title"] as? String
            self.videoInfo["duration"] = vInfo["duration"] as? String
            self.videoInfo["poster"] = vInfo["poster"] as? String
            self.videoInfo["url"] = vInfo["url"] as? String
            self.videoInfo["type"] = vInfo["type"] as? String
            self.videoInfo["source"] = vInfo["source"] as? String
            
            print("videoInfo is \(self.videoInfo)")
            
            guard let videoURLStr = self.videoInfo["url"] where videoURLStr.characters.count > 0 else { return }
                                
            
            // 如果获取到视频地址
            print("video url is \(videoURLStr)")
            
            // 设置文件名
            dispatch_async(dispatch_get_main_queue(), { 
                self.title = self.videoInfo["title"]
                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(videoURLStr)"
                self.updateUI()
            })
        })
        
        print("分享内容是: \(item.attributedContentText?.string)")
    }
    
    func updateUI(){
        if let _ = videoInfo["url"] {
            saveLinkButton.enabled = true
            copyButton.enabled = true
        } else {
            saveLinkButton.enabled = false
            copyButton.enabled = false
        }
    }
    
    // MARK: - 解析m3u8
    func parse_m3u8(action: ShareActions)  {
        saveLinkButton.enabled = false
        copyButton.enabled = false
        activityStatusView.startAnimating()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10
        let session = NSURLSession(configuration: config)
        
        let videoURL = NSURL(string: videoInfo["url"]!)
        session.dataTaskWithRequest(NSURLRequest(URL: videoURL!), completionHandler: { (data, res, error) in
            dispatch_async(dispatch_get_main_queue(), {
                self.activityStatusView.stopAnimating()
            })
            
            guard (data != nil) else {
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                return
            }
            
            let dataInfo = String(data: data!, encoding: NSUTF8StringEncoding)
            let scaner = NSScanner(string: dataInfo!)
            scaner.scanUpToString("http", intoString: nil)
            var firstUrl:NSString?
            scaner.scanUpToString(".ts", intoString: &firstUrl)
            // 备用地址
            scaner.scanUpToString("keyframe=1", intoString: nil)
            // 移到关键帧
            scaner.scanUpToString("http", intoString: nil)
            var video_url:NSString?
            scaner.scanUpToString(".ts", intoString: &video_url)
            
            print("videoURL is \(video_url)")
            
            if video_url == nil {
                video_url = firstUrl
            }
            
            guard (video_url != nil) && video_url!.hasSuffix("mp4") else {
                let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: nil)
                self.showAlert(NSLocalizedString("Parse Failed", comment: "地址解析失败"), message: nil, actions: [cancelAction])
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.videoInfo["url"] = video_url! as String
                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(video_url!)";
                switch action {
                case .Copy:
                    UIPasteboard.generalPasteboard().string = video_url! as String
                    self.hideExtensionWithCompletionHandler()
                case .Save:
                    self.startSave()
                }
            })
        }).resume()
    }
    
    // MARK: - 解析xml
    func parseXML(action: ShareActions)  {
        saveLinkButton.enabled = false
        copyButton.enabled = false
        activityStatusView.startAnimating()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10
        let session = NSURLSession(configuration: config)
        let videoURL = NSURL(string: videoInfo["url"]!)
        session.dataTaskWithRequest(NSURLRequest(URL: videoURL!), completionHandler: { (data, res, error) in
            dispatch_async(dispatch_get_main_queue(), {
                self.activityStatusView.stopAnimating()
            })
            
            guard (data != nil) else {
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                let xmlParser = NSXMLParser(data: data!)
                xmlParser.delegate = self
                if !xmlParser.parse() {
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: nil)
                    self.showAlert(NSLocalizedString("Parse Failed", comment: "地址解析失败"), message: nil, actions: [cancelAction])
                }
            })
        }).resume()
    }
    
    // MARK: - 解析iframe
    func parse_iframe(action: ShareActions) {
        saveLinkButton.enabled = false
        copyButton.enabled = false
        activityStatusView.startAnimating()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10
        let session = NSURLSession(configuration: config)
        let videoURL = NSURL(string: videoInfo["url"]!)
        session.dataTaskWithRequest(NSURLRequest(URL: videoURL!), completionHandler: { (data, res, error) in
            dispatch_async(dispatch_get_main_queue(), {
                self.activityStatusView.stopAnimating()
            })
            
            guard (data != nil) else {
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                return
            }
            
            let dataInfo = String(data: data!, encoding: NSUTF8StringEncoding)
            let scaner = NSScanner(string: dataInfo!)
            scaner.scanUpToString("poster=", intoString: nil)
            scaner.scanUpToString("http", intoString: nil)
            var poster: NSString?
            scaner.scanUpToString(" ", intoString: &poster)
            
            scaner.scanUpToString("duration", intoString: nil)
            var durationDic: NSString?
            scaner.scanUpToString(",", intoString: &durationDic)
            var duration = durationDic?.componentsSeparatedByString(":").last
            
            scaner.scanUpToString("source src=", intoString: nil)
            scaner.scanUpToString("http", intoString: nil)
            var vURL:NSString?
            scaner.scanUpToString(" ", intoString: &vURL)
            
//                print("dateinfo: \(dataInfo)")
            print("poster: \(poster)")
            print("videoURL: \(vURL)")
            print("duration: \(duration)")
            
            guard vURL != nil && poster != nil && duration != nil else {
                let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: nil)
                self.showAlert(NSLocalizedString("Parse Failed", comment: "地址解析失败"), message: nil, actions: [cancelAction])
                return
            }
            
            // 去掉最后一位 \" \' 
            vURL = vURL!.substringToIndex(vURL!.length - 1)
            poster = poster!.substringToIndex(poster!.length - 1)
            duration = self.seconds2time(Int(duration!)!)
            
            
            let comps = vURL!.componentsSeparatedByString("/")
            let lastCom = comps.last
            
            dispatch_async(dispatch_get_main_queue(), {
                self.videoInfo["url"] = vURL! as String
                self.videoInfo["poster"] = poster! as String
                self.videoInfo["duration"] = duration! as String
                self.videoInfo["title"] = lastCom
                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(vURL!)";
                switch action {
                case .Copy:
                    UIPasteboard.generalPasteboard().string = vURL! as String
                    self.hideExtensionWithCompletionHandler()
                case .Save:
                    self.startSave()
                }
            })
        }).resume()
    }
    
    
    // MARK: - 添加到视频标签列表
    @IBAction func saveToVideoMarks(sender: UIBarButtonItem) {
        userAction = ShareActions.Save
        
        // 找不到shareUrl 提示用户无法使用插件
        guard (videoInfo["url"] != nil) else {
            let alC = UIAlertController.init(title: NSLocalizedString("Can't fetch video link", comment: "无法获取到视频地址"), message: nil, preferredStyle: .Alert)
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: { (action) in
                self.hideExtensionWithCompletionHandler()
                
            })
            alC.addAction(cancelAction)
            self.presentViewController(alC, animated: true, completion: nil)
            return
        }
        
        
        if (videoInfo["type"] == "xml") {
            // 是否为twimg的xml文件
            parseXML(userAction)
        } else if (videoInfo["type"] == "iframe") {
            // 是否为twimg的xml文件
            parse_iframe(userAction)
        } else {
             startSave()
        }
    }
    
    func startSave() {
        saveMark(videoInfo)
    }
    
    func loadMarkList() -> [[String:String]]? {
        
        // #### 请替换为自己的App Group ID ####
        let groupDefaults = NSUserDefaults.init(suiteName: Constant.appGroupID)!
        
        if let jsonData:NSData = groupDefaults.objectForKey("savedMarks") as? NSData {
            do {
                guard let jsonArray:NSArray = try NSJSONSerialization.JSONObjectWithData(jsonData, options: .AllowFragments) as? NSArray else { return nil}
                return jsonArray as? [[String : String]]
            } catch {
                print("获取UserDefault出错")
            }
        }
        
        return nil
    }
    
    func saveMark(mark:[String:String]) {
        // #### 请替换为自己的App Group ID ####
        let groupDefaults = NSUserDefaults.init(suiteName: Constant.appGroupID)!
        
        var markList = loadMarkList()
        
        if markList != nil {
            markList!.append(mark)
        } else {
            markList = [mark]
        }
        
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(markList!, options: .PrettyPrinted)
            groupDefaults.setObject(jsonData, forKey: "savedMarks")
            groupDefaults.synchronize()
        } catch {
            print("保存UserDefault出错")
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: nil)
            showAlert(NSLocalizedString("Save Failed", comment: "保存出错"), message: nil, actions: [cancelAction])
        }
        
        hideExtensionWithCompletionHandler()
    }
    
    // MARK: - 复制视频链接到粘贴板
    @IBAction func copyLinksToPasteboard(sender: AnyObject) {
        userAction = .Copy
        // 找不到shareUrl 提示用户无法使用插件
        // 禁止用户下载
        guard (videoInfo["url"] != nil) else {
            self.copyButton.enabled = false
            let alC = UIAlertController.init(title: NSLocalizedString("Can't fetch video link", comment: "无法获取到视频地址"), message: NSLocalizedString("Operation Failed", comment: "操作失败"), preferredStyle: .Alert)
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: { (action) in
                self.hideExtensionWithCompletionHandler()
            })
            alC.addAction(cancelAction)
            self.presentViewController(alC, animated: true, completion: nil)
            return
        }
        
        if (videoInfo["type"] == "xml") {
            parseXML(userAction)
        } else if (videoInfo["type"] == "iframe") {
            parse_iframe(userAction)
        } else {
            UIPasteboard.generalPasteboard().string = videoInfo["url"]
            self.hideExtensionWithCompletionHandler()
        }
    }
    
    // MARK: - 取消
    @IBAction func cancel(sender: UIBarButtonItem) {
        hideExtensionWithCompletionHandler()
    }
    
    // MARK: - 动画过渡
    func hideExtensionWithCompletionHandler() {
        dispatch_async(dispatch_get_main_queue()) {
            self.navigationItem.leftBarButtonItem?.enabled = false
            UIView.animateWithDuration(0.20, animations: { () -> Void in
                self.navigationController!.view.transform = CGAffineTransformMakeTranslation(0, self.navigationController!.view.frame.size.height)
                },completion: { sucess in
                    self.extensionContext?.completeRequestReturningItems(nil, completionHandler: nil)
            })
        }
    }
}


extension ShareViewController: NSXMLParserDelegate {
    func parser(parser: NSXMLParser, foundCDATA CDATABlock: NSData) {
        let videoURL = String(data: CDATABlock, encoding: NSUTF8StringEncoding)
        print("url is \(videoURL)")
        
        if let _ = videoURL {
            self.videoInfo["url"] = videoURL!
            self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(videoURL!)";
            if (self.userAction == ShareActions.Save) {
                self.startSave()
            } else {
                UIPasteboard.generalPasteboard().string = videoURL!
                self.hideExtensionWithCompletionHandler()
            }
        }
    }
}

extension ShareViewController {
    func seconds2time(sec: Int) -> String {
        var seconds = sec
        let hours   = seconds / 3600
        let minutes = (seconds - (hours * 3600)) / 60;
        seconds = seconds - (hours * 3600) - (minutes * 60);
        var druation = ""
        
        if (hours != 0) {
            druation = "\(hours)"+":";
        }
        if (minutes != 0 || druation != "") {
            let minutesStr = (minutes < 10 && druation != "") ? "0"+"\(minutes)" : String(minutes);
            druation += minutesStr+":";
        }
        if (druation == "") {
            druation = (seconds < 10) ? "0:0"+"\(seconds)" : "0:"+String(seconds);
        }
        else {
            druation += (seconds < 10) ? "0"+"\(seconds)" : String(seconds);
        }
        return druation;
    }
}
