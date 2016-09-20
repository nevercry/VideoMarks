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

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}

extension VideoMarkCell {
    func configFor(video: Video) {
        title.text = video.title
        createDate.text = video.createDateDescription(.short, timeStyle: .none)
        duration.text = video.durationDescription
        
        // 查看缓存里有无图片数据
        let memCache = MemoryCache.shareInstance
        
        if let imageData = memCache.object(forKey: video.poster as AnyObject) as? Data {
            let image = UIImage(data: imageData)
            poster.image = image
        } else if let imageData = video.posterImage?.data {
            let image = UIImage(data: imageData as Data)
            poster.image = image
            DispatchQueue.global(qos: .background).async(execute: {
                memCache.setObject(imageData as AnyObject, forKey: video.poster as AnyObject)
            })
        } else {
            let placeholder_image = UIImage(named: "image_placeholder")
            poster.image = placeholder_image
            
            let backUpDate = video.createAt
            DispatchQueue.global(qos: .background).async {
                var imageData: Data?
                if video.poster.isEmpty {
                    imageData = video.previewImageData(atInterval: 1) as Data?
                } else {
                    let posterURL = URL(string: video.poster)!
                    imageData = try? Data(contentsOf: posterURL)
                }
                DispatchQueue.main.async(execute: {
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
                            
                            DispatchQueue.global(qos: .background).async(execute: {
                                memCache.setObject(cropData as AnyObject, forKey: video.poster as AnyObject)
                            })
                        }
                    }
                })
            }
        }
        
        poster.contentMode = .scaleAspectFill
    }
}
