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
    
    // MARK: - 解析Vimeo视频
    func parse_vimeo(action: ShareActions) {
        saveLinkButton.enabled = false
        copyButton.enabled = false
        activityStatusView.startAnimating()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10
        let session = NSURLSession(configuration: config)
        
        guard let config_url = videoInfo["url"] else { return }
        let apiURL = NSURL(string: config_url)
        
        session.dataTaskWithRequest(NSURLRequest(URL: apiURL!), completionHandler: { (data, res, error) in
            dispatch_async(dispatch_get_main_queue(), {
                self.activityStatusView.stopAnimating()
            })
            
            if let jsonData = data {
                let json = JSON(data: jsonData)
                if let dicts = json["request"]["files"]["progressive"].array {
                    
                    let sortDicts = dicts.sort({ (a, b) -> Bool in
                        return a["width"].numberValue > b["width"].numberValue
                    })
                    
                    if let bestQualityURL = sortDicts.first?["url"].string {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.videoInfo["url"] = bestQualityURL
                            self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(bestQualityURL)";
                            switch action {
                            case .Copy:
                                UIPasteboard.generalPasteboard().string = bestQualityURL
                                self.hideExtensionWithCompletionHandler()
                            case .Save:
                                self.startSave()
                            }
                        })
                        
                        return
                    }
                }
            }
            
            let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
            let message = NSLocalizedString("Try again", comment: "请重试")
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: {
                action in
                self.hideExtensionWithCompletionHandler()
            })
            self.showAlert(alertTitle, message: message, actions: [cancelAction])
        }).resume()
    }
    
    // MARK: - 解析腾讯视频
    func parse_qq(action: ShareActions)  {
        saveLinkButton.enabled = false
        copyButton.enabled = false
        activityStatusView.startAnimating()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10
        let session = NSURLSession(configuration: config)
        
        let vidURL = videoInfo["url"]!
        let video_id_Range = vidURL.rangeOfString("video_id=")!
        
        let nextRange = video_id_Range.endIndex..<vidURL.characters.endIndex
        
        let endOfvidRange = videoInfo["url"]!.rangeOfString("&", options: .LiteralSearch, range: nextRange)!
        
        let vidRange = video_id_Range.endIndex..<endOfvidRange.startIndex
        
        let vid = vidURL.substringWithRange(vidRange)
        
        print("vid is \(vid)")
        
        let api = "http://h5vv.video.qq.com/getinfo?otype=json&platform=10901&vid=\(vid)"
        let apiURL = NSURL(string: api)
        
        session.dataTaskWithRequest(NSURLRequest(URL: apiURL!), completionHandler: { (data, res, error) in
            dispatch_async(dispatch_get_main_queue(), {
                self.activityStatusView.stopAnimating()
            })
            
            if let networkData = data {
                
                let dataInfo = String(data: networkData, encoding: NSUTF8StringEncoding)
                let scaner = NSScanner(string: dataInfo!)
                scaner.scanUpToString("{", intoString: nil)
                var jsonString:NSString?
                scaner.scanUpToString("};", intoString: &jsonString)
                jsonString = jsonString?.stringByAppendingString("}")
                
                let json = JSON.parse(jsonString as! String)
                
                print("json \(json)")
                
                if let url = json["vl"]["vi"][0]["ul"]["ui"][0]["url"].string, let fvKey = json["vl"]["vi"][0]["fvkey"].string {
                    
                    var end_part:String
                    if let mp4 = json["vl"]["vi"][0]["cl"]["ci"].array {
                        end_part = mp4[0]["keyid"].string!.stringByReplacingOccurrencesOfString(".10", withString: ".p") + ".mp4"
                    } else {
                        end_part = json["vl"]["vi"][0]["fn"].string!
                    }
                    
                    let parsedURL = "\(url)/\(end_part)?vkey=\(fvKey)"
                    
                    print("parsedURL \(parsedURL)")
                    
                    let td = json["vl"]["vi"][0]["td"].string!
                    let duration = Int(Double(td)!)
                    
                    print("url \(url) endPart \(end_part) ")
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        self.videoInfo["duration"] = self.seconds2time(duration)
                        self.videoInfo["url"] = parsedURL
                        
                        self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(parsedURL)";
                        switch action {
                        case .Copy:
                            UIPasteboard.generalPasteboard().string = parsedURL
                            self.hideExtensionWithCompletionHandler()
                        case .Save:
                            self.startSave()
                        }
                    })
                    
                    return
                }
            }
            
            let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
            let message = NSLocalizedString("Try again", comment: "请重试")
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: {
                action in
                self.hideExtensionWithCompletionHandler()
            })
            self.showAlert(alertTitle, message: message, actions: [cancelAction])
            
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
        
        parse(userAction)
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
        
        parse(userAction)
    }
    
    // MARK: - 解析动作
    func parse(userAction: ShareActions) {
        if (videoInfo["type"] == "xml") {
            parseXML(userAction)
        } else if (videoInfo["type"] == "iframe") {
            parse_iframe(userAction)
        } else if (videoInfo["type"] == "qq") {
            parse_qq(userAction)
        } else if (videoInfo["type"] == "vimeo") {
            parse_vimeo(userAction)
        } else {
            switch userAction {
            case .Copy:
                UIPasteboard.generalPasteboard().string = videoInfo["url"]
                self.hideExtensionWithCompletionHandler()
            case .Save:
                startSave()
            }
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
