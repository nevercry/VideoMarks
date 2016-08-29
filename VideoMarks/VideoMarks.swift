//
//  VideoMarks.swift
//  VideoMarks
//
//  Created by nevercry on 7/13/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

struct VideoMarks {
    //MARK: - 通知
    static let CoreDataStackCompletion = "CoreDataStackCompletion"
    
    //MARK: - 尺寸
    static let DetailPosterImageSize = CGSize(width: 240, height: 135)
    static let PosterImageSize = CGSize(width: 128, height: 72)
    
    static let VideoMarkCellRowHeight: CGFloat = 90
    
    //MARK: - CellIdentifier
    static let VideoMarkCellID = "VideoMarkCell"
//    static let GirdViewCellID = "GirdViewCell"
    
    static let AllVideoCell = "AllVideoCell"
    static let CollectionCell = "CollectionCell"
    
    // MARK: - Segue
    static let ShowAllVideos = "showAllVideos"
    static let ShowColleciton = "showCollection"
    
    
    // 
    static func documentURL() -> NSURL? {
        return NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first
    }
}


enum DownloadTaskNotification: String {
    
    case Progress = "downloadNotificationProgress"
    case Finish = "downloadNotificationFinish"
    
}