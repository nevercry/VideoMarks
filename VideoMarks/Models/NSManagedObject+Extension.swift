//
//  NSManagedObject+Extension.swift
//  VideoMarks
//
//  Created by nevercry on 6/8/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObject {
    public class func entityName() -> String {
        // NSStringFromClass is available in Swift 2.
        // If the data model is in a framework, then
        // the module name needs to be stripped off.
        //
        // Example:
        //   FooBar.Engine
        //   Engine
        let name = NSStringFromClass(self)
        return name.components(separatedBy: ".").last!
    }
    
    convenience init(managedObjectContext: NSManagedObjectContext) {
        let entityName = type(of: self).entityName()
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedObjectContext)!
        self.init(entity: entity, insertInto: managedObjectContext)
    }
}
