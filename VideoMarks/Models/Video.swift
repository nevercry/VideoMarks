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
    
}

extension Video {
    var player: AVPlayer {
        let url = URL(string: self.url)
        return AVPlayer(url: url!)
    }
    
    var durationDescription: String {
        let durationPrefix = NSLocalizedString("Duration", comment: "时长")
        var durationDes = self.duration
        
        if durationDes.isEmpty {
            durationDes = NSLocalizedString("unknow", comment: "未知")
        }
        
        let result = "\(durationPrefix): \(durationDes)"
        return result
    }
    
    // MARK:- 在UITextView 里展示的内容
    func attributeDescriptionForTextView() -> NSAttributedString {
        let paragraphAtt = NSMutableParagraphStyle()
        let defaultPara = NSParagraphStyle.default
        paragraphAtt.alignment = defaultPara.alignment
        paragraphAtt.tabStops = defaultPara.tabStops
        paragraphAtt.lineBreakMode = .byCharWrapping
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
        
        let titleAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title1),convertFromNSAttributedStringKey(NSAttributedString.Key.paragraphStyle):paragraphAtt]
        let linkAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body),convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor):UIColor.darkGray,convertFromNSAttributedStringKey(NSAttributedString.Key.paragraphStyle):paragraphAtt]
        let dateAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1),convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor):UIColor.gray]
        let durationAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1),convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor):UIColor.gray]
        
        let titleAttributeString = NSAttributedString(string: "\(self.title!)", attributes: convertToOptionalNSAttributedStringKeyDictionary(titleAtts))
        let linkDes = NSAttributedString(string: "\n\(self.url)", attributes: convertToOptionalNSAttributedStringKeyDictionary(linkAtts))
        let dateDes = NSAttributedString(string: "\n\n\(self.createDateDescription(.short,timeStyle: .short))", attributes: convertToOptionalNSAttributedStringKeyDictionary(dateAtts))
        let durationDes = NSMutableAttributedString(string: "\n\(self.durationDescription)", attributes: convertToOptionalNSAttributedStringKeyDictionary(durationAtts))
        
        let combineStr = NSMutableAttributedString(attributedString: titleAttributeString)
        combineStr.append(linkDes)
        combineStr.append(dateDes)
        combineStr.append(durationDes)
        
        if let image = self.posterImage {
            let image = UIImage(data: image.data as Data)
            let attach = NSTextAttachment()
            attach.image = image
            attach.bounds = CGRect(x: 0, y: 0, width: VideoMarksConstants.DetailPosterImageSize.width, height: VideoMarksConstants.DetailPosterImageSize.height)
            combineStr.append(NSAttributedString(string: "\n"))
            let imgDes = NSAttributedString(attachment: attach)
            combineStr.append(imgDes)
        }
        
        return combineStr
    }
    
    func createDateDescription(_ dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let dateStr = DateFormatter.localizedString(from: self.createAt as Date, dateStyle: dateStyle, timeStyle: timeStyle)
        let addDateStr = NSLocalizedString("Add Date", comment: "添加日期")
        let result =  "\(addDateStr): \(dateStr)"
        return result
    }
    
    func heightForTableView(_ drawWidth: CGFloat) -> CGFloat {
        let titleAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title1)]
        let linkAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)]
        let dateAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)]
        let durationAtts = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)]
        
        let titleAttributeString = NSAttributedString(string: "\(self.title!)", attributes: convertToOptionalNSAttributedStringKeyDictionary(titleAtts))
        let linkDes = NSAttributedString(string: "\n\(self.url)", attributes: convertToOptionalNSAttributedStringKeyDictionary(linkAtts))
        let dateDes = NSAttributedString(string: "\n\n\(self.createDateDescription(.short,timeStyle: .short))", attributes: convertToOptionalNSAttributedStringKeyDictionary(dateAtts))
        let durationDes = NSMutableAttributedString(string: "\n\(self.durationDescription)", attributes: convertToOptionalNSAttributedStringKeyDictionary(durationAtts))
        
        let drawSize = CGSize(width: drawWidth, height: CGFloat(INT_MAX))
        let drawOpts:NSStringDrawingOptions = [.usesLineFragmentOrigin]
        
        let titleHeight = titleAttributeString.boundingRect(with: drawSize, options: drawOpts, context: nil).height
        let linkHeight = linkDes.boundingRect(with: drawSize, options: drawOpts, context: nil).height
        let dateHeight = dateDes.boundingRect(with: drawSize, options: drawOpts, context: nil).height
        
        if let image = self.posterImage {
            let image = UIImage(data: image.data as Data)
            let attach = NSTextAttachment()
            attach.image = image
            attach.bounds = CGRect(x: 0, y: 0, width: VideoMarksConstants.DetailPosterImageSize.width, height: VideoMarksConstants.DetailPosterImageSize.height)
            durationDes.mutableString.append("\n")
            durationDes.append(NSAttributedString(attachment: attach))
        }
        
        let druationHeight = durationDes.boundingRect(with: drawSize, options: drawOpts, context: nil).height
        
        return titleHeight + linkHeight + dateHeight + druationHeight
    }

    
    func previewImageData(atInterval interval: Int) -> Data? {
        print("Taking pic at \(interval) second")
        let videoURL = URL(string: self.url)!
        let asset = AVURLAsset(url: videoURL)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        
        var time = asset.duration
        //If possible - take not the first frame (it could be completely black or white on camara's videos)
        let tmpTime = CMTimeMakeWithSeconds(Float64(interval), preferredTimescale: 100)
        time.value = min(time.value, tmpTime.value)
        
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            let frameImg = UIImage(cgImage: img)
            let compressImage = frameImg.clipAndCompress(64.0/44.0, compressionQuality: 1.0)
            let newImageSize = CGSize(width: 320, height: 220)
            UIGraphicsBeginImageContextWithOptions(newImageSize, false, 0.0)
            compressImage.draw(in: CGRect(x: 0, y: 0, width: newImageSize.width, height: newImageSize.height))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage!.jpegData(compressionQuality: 1.0)
        } catch {
            /* error handling here */
            print("获取视频截图失败")
        }
        return nil
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
