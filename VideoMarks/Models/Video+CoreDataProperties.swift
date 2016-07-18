//
//  Video+CoreDataProperties.swift
//  VideoMarks
//
//  Created by nevercry on 6/8/16.
//  Copyright © 2016 nevercry. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Video {

    @NSManaged var createAt: NSDate
    @NSManaged var isFavorite: NSNumber
    @NSManaged var title: String?
    @NSManaged var url: String
    @NSManaged var source: String
    @NSManaged var poster: String
    @NSManaged var duration: String
    @NSManaged var posterImage: Image?
    
    convenience init(url: String,
                     source: String,
                     title: String?,
                     poster: String,
                     duration: String,
                     isFavorite: NSNumber = NSNumber(bool: false),
                     createAt: NSDate = NSDate(), context: NSManagedObjectContext) {
        self.init(managedObjectContext: context)
        self.url = url
        self.source = source
        self.title = title
        self.isFavorite = isFavorite
        self.createAt = createAt
        self.duration = duration
        self.poster = poster
    }
    
    convenience init(videoInfo: [String: String], context: NSManagedObjectContext) {
        let url = videoInfo["url"]!
        var tmpTitle = videoInfo["title"] // 希望截取的标题不要换行。
        tmpTitle = tmpTitle?.stringByReplacingOccurrencesOfString("\n", withString: "")
        tmpTitle = tmpTitle?.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
        let title = tmpTitle
        var duration = videoInfo["duration"]!
        duration = duration.stringByReplacingOccurrencesOfString("时长: ", withString: "")
        let poster = videoInfo["poster"]!
        let source = videoInfo["source"]!
        self.init(url: url,
                  source: source,
                  title: title,
                  poster: poster,
                  duration: duration,
                  context: context)
    }
}
