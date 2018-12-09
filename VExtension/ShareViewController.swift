//
//  ShareViewController.swift
//  VExtension
//
//  Created by nevercry on 6/5/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import MobileCoreServices
import SwiftyJSON

struct Constant {
    static let appGroupID = "group.nevercry.videoMarks"
    static let kSaveMarks = "savedMarks"
}


class ShareViewController: UIViewController {
    
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var activityStatusView: UIActivityIndicatorView!
    @IBOutlet weak var LinkLabel: UILabel!
    @IBOutlet weak var saveLinkButton: UIBarButtonItem!
    
    var userAction: ShareActions = .save
    
    enum ShareActions: Int {
        case save,copy
    }
    
    var videoInfo: [String: String] = [:]  // Keys: "url","type","poster","duration","title"，“source”
    
    // MARK: 显示没有URL的警告
    func showNoURLAlert() {
        let alertTitle = NSLocalizedString("Can't fetch video link", comment: "无法获取到视频地址")
        let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: { (action) in
            self.hideExtensionWithCompletionHandler()
            
        })
        showAlert(alertTitle, message: nil, actions: [cancelAction])
    }
    
    // MARK: 显示警告
    func showAlert(_ title:String?, message: String?, actions: [UIAlertAction])  {
        let alC = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
        for (_,action) in actions.enumerated() {
            alC.addAction(action)
        }
        DispatchQueue.main.async {
            self.present(alC, animated: true, completion: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.transform = CGAffineTransform(translationX: 0, y: self.view.frame.size.height)
        UIView.animate(withDuration: 0.25, animations: { () -> Void in
            self.view.transform = CGAffineTransform.identity
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        activityStatusView.stopAnimating()
        
        
        // 判断输入的类型
        
        if let unKnowItem = extensionContext?.inputItems.first as? NSExtensionItem {
            
            if let unKnowItemProvider = unKnowItem.attachments?.first {
                
                let kPlainText = String(kUTTypePlainText)
                
                if unKnowItemProvider.hasItemConformingToTypeIdentifier(kPlainText) {
                    // 纯文本
                    
                    unKnowItemProvider.loadItem(forTypeIdentifier: kPlainText, options: nil) { (plainText, error) in
                        
                        if let shareText = plainText as? NSString {
                            
                            print(shareText)
                        }
 
                        
                    }
                    
                    
                    
                }
                
                
                let kUrl = String(kUTTypeURL)
                
                if unKnowItemProvider.hasItemConformingToTypeIdentifier(kUrl) {
                    // URL
                    
                    unKnowItemProvider.loadItem(forTypeIdentifier: kUrl, options: nil) { (url, error) in
                        
                        if let shareURL = url as? NSURL {
                            
                            self.videoInfo = self.makeURLToVideoInfo(url:shareURL)
                            
                            
                            guard let videoURLStr = self.videoInfo["url"] , videoURLStr.count > 0 else { return }
                            
                            
                            // 如果获取到视频地址
                            print("video url is \(videoURLStr)")
                            
                            // 设置文件名
                            DispatchQueue.main.async(execute: {
                                self.title = self.videoInfo["title"]
                                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(videoURLStr)"
                                self.updateUI()
                            })
                            
                            
                            
                        }
                        
                    }
                    
                }
                
            }
            
            
            
            
        }
        
        
        
        
        
        
        
        
        let propertyList = String(kUTTypePropertyList)
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let itemProvider = item.attachments?.first , itemProvider.hasItemConformingToTypeIdentifier(propertyList) else { return }
        
        itemProvider.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (diction, error) in
            guard let shareDic = diction as? NSDictionary,
            let results = shareDic.object(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary,
            let vInfo = results.object(forKey: "videoInfo") as? NSDictionary else { return }
            // 视频信息
            self.videoInfo["title"] = vInfo["title"] as? String
            self.videoInfo["duration"] = vInfo["duration"] as? String
            self.videoInfo["poster"] = vInfo["poster"] as? String
            self.videoInfo["url"] = vInfo["url"] as? String
            self.videoInfo["type"] = vInfo["type"] as? String
            self.videoInfo["source"] = vInfo["source"] as? String
            
            print("videoInfo is \(self.videoInfo)")
            
            guard let videoURLStr = self.videoInfo["url"] , videoURLStr.count > 0 else { return }
                                
            
            // 如果获取到视频地址
            print("video url is \(videoURLStr)")
            
            // 设置文件名
            DispatchQueue.main.async(execute: { 
                self.title = self.videoInfo["title"]
                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(videoURLStr)"
                self.updateUI()
            })
        })
        
        print("分享内容是: \(String(describing: item.attributedContentText?.string))")
    }
    
    func makeURLToVideoInfo(url: NSURL) -> [String: String] {
        var videoInfo = [String:String]()
        videoInfo["title"] = url.description
        
    
        // 判断url 属于哪个视频服务
        
        let hostName = url.host
        
        if hostName!.contains("twitter") {
           // twitter 视频
            let tweet_id = url.lastPathComponent!
            
            videoInfo["url"] = "https://api.twitter.com/1.1/statuses/show/" + tweet_id + ".json?tweet_mode=extended";
            videoInfo["type"] = "twitter"
        }
        
        return videoInfo

    }
    
    func updateUI(){
        if let _ = videoInfo["url"] {
            saveLinkButton.isEnabled = true
            copyButton.isEnabled = true
        } else {
            saveLinkButton.isEnabled = false
            copyButton.isEnabled = false
        }
    }
    
    // MARK: - 解析Twitter视频
    func parse_twitter(_ action: ShareActions)  {
        saveLinkButton.isEnabled = false
        copyButton.isEnabled = false
        activityStatusView.startAnimating()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        guard let config_url = videoInfo["url"] else { return }
        var tweetRequest = URLRequest(url: URL(string: config_url)!)
        let bearString = "Bearer AAAAAAAAAAAAAAAAAAAAABXsygAAAAAAmJuTUyoBiQiFqw9KIVOZPoELi%2FM%3DPau8s2HiUxM9v3eiOtJQu3bdKcCbaHyw5le0yH1LLhfJh6580X"
        tweetRequest.addValue(bearString, forHTTPHeaderField: "Authorization")
        
        session.dataTask(with: tweetRequest) { (data, res, error) in
            DispatchQueue.main.async(execute: {
                self.activityStatusView.stopAnimating()
            })
            
            do {
                
                if let jsonData = data {
                    let json = try JSON(data: jsonData)
                    
                    self.videoInfo["title"] = json["full_text"].stringValue
                    
                    if let mediaInfo = json["extended_entities"]["media"][0].dictionary {
                        
                        self.videoInfo["poster"] = mediaInfo["media_url"]!.string!
                        
                        
                        
                        if let vInfo = mediaInfo["video_info"]?.dictionary {
                            
                            let milisec = vInfo["duration_millis"]!.number!.intValue
                            
                            self.videoInfo["duration"] = self.seconds2time(milisec/1000)
                            
                            if let variants = vInfo["variants"]?.array {
                                
                                var bestQualityURL = ""
                                
                                var highBitrate = 0
                                
                                for var elem in variants {
                                    
                                    if let videoType = elem["content_type"].string {
                                        
                                        if videoType == "video/mp4" {
                                            
                                            if let videoBitrate = elem["bitrate"].int {
                                                
                                                if videoBitrate > highBitrate {
                                                    
                                                    highBitrate = videoBitrate
                                                    
                                                    bestQualityURL = elem["url"].stringValue
                                                    
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if bestQualityURL.count > 0 {
                                    
                                    DispatchQueue.main.async(execute: {
                                        self.videoInfo["url"] = bestQualityURL
                                        self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(bestQualityURL)";
                                        self.title = self.videoInfo["title"]
                                        switch action {
                                        case .copy:
                                            UIPasteboard.general.string = bestQualityURL
                                            self.hideExtensionWithCompletionHandler()
                                            self.tryOpenVideoMarks()
                                        case .save:
                                            self.startSave()
                                        }
                                    })
                                    
                                    return
                                }
                                
                            }
                            
                            
                        }
                        
                    }
                }
                
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                
            }
                
            catch {
                
            }
            
        }.resume()
    }
    
    // MARK: - 解析Vimeo视频
    func parse_vimeo(_ action: ShareActions) {
        saveLinkButton.isEnabled = false
        copyButton.isEnabled = false
        activityStatusView.startAnimating()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        guard let config_url = videoInfo["url"] else { return }
        let apiURL = URL(string: config_url)
        
        session.dataTask(with: URLRequest(url: apiURL!), completionHandler: { (data, res, error) in
            DispatchQueue.main.async(execute: {
                self.activityStatusView.stopAnimating()
            })
            
            do {
                
                if let jsonData = data {
                    let json = try JSON(data: jsonData)
                    if let dicts = json["request"]["files"]["progressive"].array {
                        
                        let sortDicts = dicts.sorted(by: { (a, b) -> Bool in
                            
                            let aWidth = a["width"].numberValue.intValue, bWidth = b["width"].numberValue.intValue
                            
                            return aWidth > bWidth
                        })
                        
                        if let bestQualityURL = sortDicts.first?["url"].string {
                            DispatchQueue.main.async(execute: {
                                self.videoInfo["url"] = bestQualityURL
                                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(bestQualityURL)";
                                switch action {
                                case .copy:
                                    UIPasteboard.general.string = bestQualityURL
                                    self.hideExtensionWithCompletionHandler()
                                case .save:
                                    self.startSave()
                                }
                            })
                            
                            return
                        }
                    }
                }
                
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                
            } catch {
                
            }
            
            
        }).resume()
    }
    
    // MARK: - 解析腾讯视频
    func parse_qq(_ action: ShareActions)  {
        saveLinkButton.isEnabled = false
        copyButton.isEnabled = false
        activityStatusView.startAnimating()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        let vidURL = videoInfo["url"]!
        let video_id_Range = vidURL.range(of: "video_id=")!
        
        let nextRange = video_id_Range.upperBound..<vidURL.endIndex
        
        let endOfvidRange = videoInfo["url"]!.range(of: "&", options: .literal, range: nextRange)!
        
        let vidRange = video_id_Range.upperBound..<endOfvidRange.lowerBound
        
        let vid = vidURL[vidRange]
        
        print("vid is \(vid)")
        
        let api = "http://h5vv.video.qq.com/getinfo?otype=json&platform=10901&vid=\(vid)"
        let apiURL = URL(string: api)
        
        session.dataTask(with: URLRequest(url: apiURL!), completionHandler: { (data, res, error) in
            DispatchQueue.main.async(execute: {
                self.activityStatusView.stopAnimating()
            })
            
            if let networkData = data {
                
                let dataInfo = String(data: networkData, encoding: String.Encoding.utf8)
                let scaner = Scanner(string: dataInfo!)
                scaner.scanUpTo("{", into: nil)
                var jsonString:NSString?
                scaner.scanUpTo("};", into: &jsonString)
                jsonString = jsonString?.appending("}") as NSString?
                
                let json = JSON(parseJSON: jsonString! as String)
                
                print("json \(json)")
                
                if let url = json["vl"]["vi"][0]["ul"]["ui"][0]["url"].string, let fvKey = json["vl"]["vi"][0]["fvkey"].string {
                    
                    var end_part:String
                    if let mp4 = json["vl"]["vi"][0]["cl"]["ci"].array {
                        end_part = mp4[0]["keyid"].string!.replacingOccurrences(of: ".10", with: ".p") + ".mp4";
                    } else {
                        end_part = json["vl"]["vi"][0]["fn"].string!
                    }
                    
                    let parsedURL = "\(url)/\(end_part)?vkey=\(fvKey)"
                    
                    print("parsedURL \(parsedURL)")
                    
                    let td = json["vl"]["vi"][0]["td"].string!
                    let duration = Int(Double(td)!)
                    
                    print("url \(url) endPart \(end_part) ")
                    
                    DispatchQueue.main.async(execute: {
                        self.videoInfo["duration"] = self.seconds2time(duration)
                        self.videoInfo["url"] = parsedURL
                        
                        self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(parsedURL)";
                        switch action {
                        case .copy:
                            UIPasteboard.general.string = parsedURL
                            self.hideExtensionWithCompletionHandler()
                        case .save:
                            self.startSave()
                        }
                    })
                    
                    return
                }
            }
            
            let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
            let message = NSLocalizedString("Try again", comment: "请重试")
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: {
                action in
                self.hideExtensionWithCompletionHandler()
            })
            self.showAlert(alertTitle, message: message, actions: [cancelAction])
            
        }).resume()
    }
    
    // MARK: - 解析xml
    func parseXML(_ action: ShareActions)  {
        saveLinkButton.isEnabled = false
        copyButton.isEnabled = false
        activityStatusView.startAnimating()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        let videoURL = URL(string: videoInfo["url"]!)
        session.dataTask(with: URLRequest(url: videoURL!), completionHandler: { (data, res, error) in
            DispatchQueue.main.async(execute: {
                self.activityStatusView.stopAnimating()
            })
            
            guard (data != nil) else {
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                return
            }
            
            DispatchQueue.main.async(execute: {
                let xmlParser = XMLParser(data: data!)
                xmlParser.delegate = self
                if !xmlParser.parse() {
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: nil)
                    self.showAlert(NSLocalizedString("Parse Failed", comment: "地址解析失败"), message: nil, actions: [cancelAction])
                }
            })
        }).resume()
    }
    
    // MARK: - 解析iframe
    func parse_iframe(_ action: ShareActions) {
        saveLinkButton.isEnabled = false
        copyButton.isEnabled = false
        activityStatusView.startAnimating()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        let videoURL = URL(string: videoInfo["url"]!)
        session.dataTask(with: URLRequest(url: videoURL!), completionHandler: { (data, res, error) in
            DispatchQueue.main.async(execute: {
                self.activityStatusView.stopAnimating()
            })
            
            guard (data != nil) else {
                let alertTitle = NSLocalizedString("Operation Failed", comment: "操作失败")
                let message = NSLocalizedString("Try again", comment: "请重试")
                let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: {
                    action in
                    self.hideExtensionWithCompletionHandler()
                })
                self.showAlert(alertTitle, message: message, actions: [cancelAction])
                return
            }
            
            let dataInfo = String(data: data!, encoding: String.Encoding.utf8)
            let scaner = Scanner(string: dataInfo!)
            scaner.scanUpTo("poster=", into: nil)
            scaner.scanUpTo("http", into: nil)
            var poster: NSString?
            scaner.scanUpTo(" ", into: &poster)
            
            scaner.scanUpTo("duration", into: nil)
            var durationDic: NSString?
            scaner.scanUpTo(",", into: &durationDic)
            var duration = durationDic?.components(separatedBy: ":").last
            
            scaner.scanUpTo("source src=", into: nil)
            scaner.scanUpTo("http", into: nil)
            var vURL:NSString?
            scaner.scanUpTo(" ", into: &vURL)
            
//                print("dateinfo: \(dataInfo)")
            print("poster: \(String(describing: poster))")
            print("videoURL: \(String(describing: vURL))")
            print("duration: \(String(describing: duration))")
            
            guard vURL != nil && poster != nil && duration != nil else {
                let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: nil)
                self.showAlert(NSLocalizedString("Parse Failed", comment: "地址解析失败"), message: nil, actions: [cancelAction])
                return
            }
            
            // 去掉最后一位 \" \' 
            vURL = vURL!.substring(to: vURL!.length - 1) as NSString?
            poster = poster!.substring(to: poster!.length - 1) as NSString?
            duration = self.seconds2time(Int(duration!)!)
            
            
            let comps = vURL!.components(separatedBy: "/")
            let lastCom = comps.last
            
            DispatchQueue.main.async(execute: {
                self.videoInfo["url"] = vURL! as String
                self.videoInfo["poster"] = poster! as String
                self.videoInfo["duration"] = duration! as String
                self.videoInfo["title"] = lastCom
                self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(vURL!)";
                switch action {
                case .copy:
                    UIPasteboard.general.string = vURL! as String
                    self.hideExtensionWithCompletionHandler()
                case .save:
                    self.startSave()
                }
            })
        }).resume()
    }
    
    
    // MARK: - 添加到视频标签列表
    @IBAction func saveToVideoMarks(_ sender: UIBarButtonItem) {
        userAction = ShareActions.save
        
        // 找不到shareUrl 提示用户无法使用插件
        guard (videoInfo["url"] != nil) else {
            let alC = UIAlertController.init(title: NSLocalizedString("Can't fetch video link", comment: "无法获取到视频地址"), message: nil, preferredStyle: .alert)
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: { (action) in
                self.hideExtensionWithCompletionHandler()
                
            })
            alC.addAction(cancelAction)
            self.present(alC, animated: true, completion: nil)
            return
        }
        
        parse(userAction)
    }
    
    func startSave() {
        saveMark(videoInfo)
    }
    
    func loadMarkList() -> [[String:String]]? {
        
        // #### 请替换为自己的App Group ID ####
        let groupDefaults = UserDefaults.init(suiteName: Constant.appGroupID)!
        
        if let jsonData:Data = groupDefaults.object(forKey: Constant.kSaveMarks) as? Data {
            do {
                guard let jsonArray:NSArray = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? NSArray else { return nil}
                return jsonArray as? [[String : String]]
            } catch {
                print("获取UserDefault出错")
            }
        }
        
        return nil
    }
    
    func saveMark(_ mark:[String:String]) {
        // #### 请替换为自己的App Group ID ####
        let groupDefaults = UserDefaults.init(suiteName: Constant.appGroupID)!
        
        var markList = loadMarkList()
        
        if markList != nil {
            markList!.append(mark)
        } else {
            markList = [mark]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: markList!, options: .prettyPrinted)
            groupDefaults.set(jsonData, forKey: Constant.kSaveMarks)
            groupDefaults.synchronize()
        } catch {
            print("保存UserDefault出错")
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: nil)
            showAlert(NSLocalizedString("Save Failed", comment: "保存出错"), message: nil, actions: [cancelAction])
        }
        
        hideExtensionWithCompletionHandler()
    }
    
    // MARK: - 复制视频链接到粘贴板
    @IBAction func copyLinksToPasteboard(_ sender: AnyObject) {
        userAction = .copy
        // 找不到shareUrl 提示用户无法使用插件
        // 禁止用户下载
        guard (videoInfo["url"] != nil) else {
            self.copyButton.isEnabled = false
            let alC = UIAlertController.init(title: NSLocalizedString("Can't fetch video link", comment: "无法获取到视频地址"), message: NSLocalizedString("Operation Failed", comment: "操作失败"), preferredStyle: .alert)
            let cancelAction = UIAlertAction.init(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: { (action) in
                self.hideExtensionWithCompletionHandler()
            })
            alC.addAction(cancelAction)
            self.present(alC, animated: true, completion: nil)
            return
        }
        
        // 解析用户动作 根据类型 重新获取其中的视频真实地址
        parse(userAction)
    }
    
    // MARK: - 解析动作
    func parse(_ userAction: ShareActions) {
        if (videoInfo["type"] == "xml") {
            parseXML(userAction)
        } else if (videoInfo["type"] == "iframe") {
            parse_iframe(userAction)
        } else if (videoInfo["type"] == "qq") {
            parse_qq(userAction)
        } else if (videoInfo["type"] == "vimeo") {
            parse_vimeo(userAction)
        } else if (videoInfo["type"] == "twitter") {
            parse_twitter(userAction)
        } else {
            switch userAction {
            case .copy:
                UIPasteboard.general.string = videoInfo["url"]
                self.hideExtensionWithCompletionHandler()
                tryOpenVideoMarks()
            case .save:
                startSave()
            }
        }
    }
    
    // MARK: - 取消
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        hideExtensionWithCompletionHandler()
    }
    
    // MARK: - 动画过渡
    func hideExtensionWithCompletionHandler() {
        DispatchQueue.main.async {
            self.navigationItem.leftBarButtonItem?.isEnabled = false
            UIView.animate(withDuration: 0.20, animations: { () -> Void in
                self.navigationController!.view.transform = CGAffineTransform(translationX: 0, y: self.navigationController!.view.frame.size.height)
                },completion: { sucess in
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            })
        }
    }
    
    // MARK: - 打开APP
    func tryOpenVideoMarks() {
        let url = NSURL(string:"videomarks://test.com")
        let context = NSExtensionContext()
        context.open(url! as URL, completionHandler: nil)
        
        var responder = self as UIResponder?
        while (responder != nil){
            if responder?.responds(to: #selector(UIApplication.openURL(_:))) == true{
                responder?.perform(#selector(UIApplication.openURL(_:)), with: url)
            }
            responder = responder!.next
        }
    }
}



extension ShareViewController: XMLParserDelegate {
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        let videoURL = String(data: CDATABlock, encoding: String.Encoding.utf8)
        print("url is \(String(describing: videoURL))")
        
        if let _ = videoURL {
            self.videoInfo["url"] = videoURL!
            self.LinkLabel.text = "\(NSLocalizedString("Link", comment: "链接")): \(videoURL!)";
            if (self.userAction == ShareActions.save) {
                self.startSave()
            } else {
                UIPasteboard.general.string = videoURL!
                self.hideExtensionWithCompletionHandler()
            }
        }
    }
}

extension ShareViewController {
    func seconds2time(_ sec: Int) -> String {
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
