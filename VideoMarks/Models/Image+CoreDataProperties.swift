//
//  Image+CoreDataProperties.swift
//  VideoMarks
//
//  Created by nevercry on 6/10/16.
//  Copyright © 2016 nevercry. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Image {

    @NSManaged var data: Data
    @NSManaged var fromVideo: Video?
    
    
    convenience init(data: Data,
                     context: NSManagedObjectContext) {
        self.init(managedObjectContext: context)
        self.data = data
    }

}
