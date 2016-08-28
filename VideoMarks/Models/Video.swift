//
//  Video.swift
//  VideoMarks
//
//  Created by nevercry on 6/8/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import AVFoundation

class Video: NSManagedObject {
    
    // MARK:- 在UITextView 里展示的内容
    func attributeDescriptionForTextView() -> NSAttributedString {
        let paragraphAtt = NSMutableParagraphStyle()
        let defaultPara = NSParagraphStyle.defaultParagraphStyle()
        paragraphAtt.alignment = defaultPara.alignment
        paragraphAtt.tabStops = defaultPara.tabStops
        paragraphAtt.lineBreakMode = .ByCharWrapping
        paragraphAtt.defaultTabInterval = defaultPara.defaultTabInterval
        paragraphAtt.firstLineHeadIndent = defaultPara.firstLineHeadIndent
        paragraphAtt.headIndent = defaultPara.headIndent
        paragraphAtt.hyphenationFactor = defaultPara.hyphenationFactor
        paragraphAtt.lineHeightMultiple = defaultPara.lineHeightMultiple
        paragraphAtt.lineSpacing = defaultPara.lineSpacing
        paragraphAtt.maximumLineHeight = defaultPara.maximumLineHeight
        paragraphAtt.minimumLineHeight = defaultPara.minimumLineHeight
        paragraphAtt.paragraphSpacing = defaultPara.paragraphSpacing
        paragraphAtt.paragraphSpacingBefore = defaultPara.paragraphSpacingBefore
        
        let titleAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleTitle1),NSParagraphStyleAttributeName:paragraphAtt]
        let linkAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleBody),NSForegroundColorAttributeName:UIColor.darkGrayColor(),NSParagraphStyleAttributeName:paragraphAtt]
        let dateAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1),NSForegroundColorAttributeName:UIColor.grayColor()]
        let durationAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1),NSForegroundColorAttributeName:UIColor.grayColor()]

        let titleAttributeString = NSAttributedString(string: "\(self.title!)", attributes: titleAtts)
        let linkDes = NSAttributedString(string: "\n\(self.url)", attributes: linkAtts)
        let dateDes = NSAttributedString(string: "\n\n\(self.createDateDescription(dateStyle: .ShortStyle,timeStyle: .ShortStyle))", attributes: dateAtts)
        var durationDes = NSMutableAttributedString(string: "\n\(self.durationDescription())", attributes: durationAtts)
        
        if let expireDes = expireAttributeDescription() {
            
            if let expInterval = expireTimeInterval() {
                if isVideoInvalid(expInterval) {
                    // 过期
                    durationDes = NSMutableAttributedString(string: "\n")
                    durationDes.appendAttributedString(expireDes)
                } else {
                    durationDes.mutableString.appendString("  ")
                    durationDes.appendAttributedString(expireDes)
                }
            }
        }

        let combineStr = NSMutableAttributedString(attributedString: titleAttributeString)
        combineStr.appendAttributedString(linkDes)
        combineStr.appendAttributedString(dateDes)
        combineStr.appendAttributedString(durationDes)
        
        if let image = self.posterImage {
            let image = UIImage(data: image.data)
            let attach = NSTextAttachment()
            attach.image = image
            attach.bounds = CGRectMake(0, 0, VideoMarks.DetailPosterImageSize.width, VideoMarks.DetailPosterImageSize.height)
            combineStr.appendAttributedString(NSAttributedString(string: "\n"))
            let imgDes = NSAttributedString(attachment: attach)
            combineStr.appendAttributedString(imgDes)
        }

        return combineStr
    }
    
    func createDateDescription(dateStyle dateStyle: NSDateFormatterStyle, timeStyle: NSDateFormatterStyle) -> String {
        let dateStr = NSDateFormatter.localizedStringFromDate(self.createAt, dateStyle: dateStyle, timeStyle: timeStyle)
        let addDateStr = NSLocalizedString("Add Date", comment: "添加日期")
        let result =  "\(addDateStr): \(dateStr)"
        return result
    }
    
    func durationDescription() -> String {
        let durationPrefix = NSLocalizedString("Duration", comment: "时长")
        var durationDes = self.duration
        
        if durationDes.isEmpty {
            durationDes = NSLocalizedString("unknow", comment: "未知")
        }
        
        let result = "\(durationPrefix): \(durationDes)"
        return result
    }
    
    func expireTimeInterval() -> NSTimeInterval? {
        var result: NSTimeInterval?
        if self.url.containsString("expire=") || self.url.containsString("expires=") {
            
            let needStr = self.url.stringByReplacingOccurrencesOfString("expires=", withString: "expire=")
            
            let scaner = NSScanner(string: needStr)
            scaner.scanUpToString("expire=", intoString: nil)
            var expPair:NSString?
            scaner.scanUpToString("&", intoString: &expPair)
                        
            if let expArr = expPair?.componentsSeparatedByString("=") {
                if expArr.count > 1 {
                    let timeInterval = expArr[1]
                    result =  NSTimeInterval(timeInterval)
                }
            }
        }
        
        return result
    }
    
    func isVideoInvalid(expTimeInterval: NSTimeInterval) -> Bool {
        return NSDate(timeIntervalSince1970: expTimeInterval).compare(NSDate()) == .OrderedAscending
    }
    
    func expireAttributeDescription() -> NSAttributedString? {
        var expireDes: NSAttributedString?
        var noAttrStr: String?
        if let expireTimeInterval = expireTimeInterval() {
            let expDate = NSDate(timeIntervalSince1970: expireTimeInterval)
            let nowDate = NSDate()
            let compFormatter = NSDateComponentsFormatter()
            compFormatter.allowedUnits = [.Hour,.Minute,.Second]
            compFormatter.unitsStyle = .Abbreviated
            let expHMS = compFormatter.stringFromDate(nowDate, toDate: expDate)
            var expAtts:[String:AnyObject] = [:]
            if isVideoInvalid(expireTimeInterval) {
                // 过期
                noAttrStr = "\(NSLocalizedString("Invalid to play", comment: "过期"))"
                expAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1),NSForegroundColorAttributeName:UIColor.redColor(),NSTextEffectAttributeName:NSTextEffectLetterpressStyle]
            } else {
                noAttrStr = "\(NSLocalizedString("Expire", comment: "过期时间")): \(expHMS!)"
                expAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1),NSForegroundColorAttributeName:UIColor.lightGrayColor()]
            }
            
            expireDes = NSAttributedString(string: noAttrStr!, attributes: expAtts)
        }
        
        return expireDes
    }
    
    func heightForTableView(drawWidth: CGFloat) -> CGFloat {
        let titleAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleTitle1)]
        let linkAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleBody)]
        let dateAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)]
        let durationAtts = [NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)]
        
        let titleAttributeString = NSAttributedString(string: "\(self.title!)", attributes: titleAtts)
        let linkDes = NSAttributedString(string: "\n\(self.url)", attributes: linkAtts)
        let dateDes = NSAttributedString(string: "\n\n\(self.createDateDescription(dateStyle: .ShortStyle,timeStyle: .ShortStyle))", attributes: dateAtts)
        var durationDes = NSMutableAttributedString(string: "\n\(self.durationDescription())", attributes: durationAtts)
        
        if let expireDes = expireAttributeDescription() {
            
            if let expInterval = expireTimeInterval() {
                if isVideoInvalid(expInterval) {
                    // 过期
                    durationDes = NSMutableAttributedString(string: "\n")
                    durationDes.appendAttributedString(expireDes)
                } else {
                    durationDes.mutableString.appendString("  ")
                    durationDes.appendAttributedString(expireDes)
                }
            }
        }
        
        let drawSize = CGSizeMake(drawWidth, CGFloat(INT_MAX))
        let drawOpts:NSStringDrawingOptions = [.UsesLineFragmentOrigin]
        
        let titleHeight = titleAttributeString.boundingRectWithSize(drawSize, options: drawOpts, context: nil).height
        let linkHeight = linkDes.boundingRectWithSize(drawSize, options: drawOpts, context: nil).height
        let dateHeight = dateDes.boundingRectWithSize(drawSize, options: drawOpts, context: nil).height
        
        if let image = self.posterImage {
            let image = UIImage(data: image.data)
            let attach = NSTextAttachment()
            attach.image = image
            attach.bounds = CGRectMake(0, 0, VideoMarks.DetailPosterImageSize.width, VideoMarks.DetailPosterImageSize.height)
            durationDes.mutableString.appendString("\n")
            durationDes.appendAttributedString(NSAttributedString(attachment: attach))
        }
        
        let druationHeight = durationDes.boundingRectWithSize(drawSize, options: drawOpts, context: nil).height
        
        return titleHeight + linkHeight + dateHeight + druationHeight 
    }
}

extension Video {
    var player: AVPlayer {
        let url = NSURL(string: self.url)
        return AVPlayer(URL: url!)
    }
    
    func previewImageData(atInterval interval: Int) -> NSData? {
        print("Taking pic at \(interval) second")
        let videoURL = NSURL(string: self.url)!
        let asset = AVURLAsset(URL: videoURL)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        
        var time = asset.duration
        //If possible - take not the first frame (it could be completely black or white on camara's videos)
        let tmpTime = CMTimeMakeWithSeconds(Float64(interval), 100)
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
