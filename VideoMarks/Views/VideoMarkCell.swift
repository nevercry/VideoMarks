//
//  VideoMarkCell.swift
//  VideoMarks
//
//  Created by nevercry on 7/13/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class VideoMarkCell: UITableViewCell {
    @IBOutlet weak var poster: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var createDate: UILabel!
    @IBOutlet weak var duration: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}

extension VideoMarkCell {
    func configFor(video video: Video) {
        title.text = video.title
        createDate.text = video.createDateDescription(dateStyle: .ShortStyle, timeStyle: .NoStyle)
        
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
        
        duration.attributedText = durationAttriStr
        
        // 查看缓存里有无图片数据
        let memCache = MemoryCache.shareInstance
        
        if let imageData = memCache.objectForKey(video.poster) as? NSData {
            let image = UIImage(data: imageData)
            poster.image = image
        } else if let imageData = video.posterImage?.data {
            let image = UIImage(data: imageData)
            poster.image = image
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { 
                memCache.setObject(imageData, forKey: video.poster)
            })
        } else {
            let tmpImg = UIImage.alphaSafariIcon(44, scale: Float(UIScreen.mainScreen().scale))
            poster.image = UIImage.resize(tmpImg, newSize: VideoMarks.PosterImageSize)
            
            let backUpDate = video.createAt
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
                var imageData: NSData?
                if video.poster.isEmpty {
                    imageData = video.previewImageData(atInterval: 1)
                } else {
                    let posterURL = NSURL(string: video.poster)!
                    imageData = NSData(contentsOfURL: posterURL)
                }
                dispatch_async(dispatch_get_main_queue(), {
                    if video.createAt == backUpDate {
                        if let _ = imageData {
                            // 根据16:9 截取图片
                            guard let preImage = UIImage(data: imageData!) else { return }
                            let cropImage = preImage.crop16_9()
                            let cropData = UIImageJPEGRepresentation(cropImage, 1)!
                            
                            let image = Image(data: cropData, context: video.managedObjectContext!)
                            image.fromVideo = video
                            
                            do {
                                try image.managedObjectContext?.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                            
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { 
                                memCache.setObject(cropData, forKey: video.poster)
                            })
                        }
                    }
                })
            }
        }
        
        poster.contentMode = .ScaleAspectFill
    }
}
