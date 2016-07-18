//
//  DataController.swift
//  VideoMarks
//
//  Created by nevercry on 6/7/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import CoreData

class DataController: NSObject {
    var managedObjectContext: NSManagedObjectContext
    var completeCallback: (()->Void)?
    
    init(callback: (()->Void)?) {
        // This resource is the same name as your xcdatamodeld contained in your project.
        
        guard let modelURL = NSBundle.mainBundle().URLForResource("VideoMarks", withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        self.managedObjectContext.persistentStoreCoordinator = psc
        self.completeCallback = callback
        
        super.init()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
            let docURL = urls[urls.endIndex-1]
            // The directory the application uses to store the Core Data store file.
            let storeURL = docURL.URLByAppendingPathComponent("VideoMarksData.sqlite")
            
            let optionsDict = [NSMigratePersistentStoresAutomaticallyOption:NSNumber(bool: true),NSInferMappingModelAutomaticallyOption:NSNumber(bool: true)]
            
            do {
                try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: optionsDict)
                
                if let _ = self.completeCallback {
                    print("core date complete!!!")
                    dispatch_async(dispatch_get_main_queue(), { 
                        self.completeCallback!()
                    })
                }
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }
    }
    
    // MARK: - Core Data Saving support
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
                
                let alertC = UIAlertController(title: NSLocalizedString("Save Error", comment: "保存失败"), message: nil, preferredStyle: .Alert)
                let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .Cancel, handler: nil)
                alertC.addAction(cancelAction)
                UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertC, animated: true, completion: nil)
            }
        }
    }
}
