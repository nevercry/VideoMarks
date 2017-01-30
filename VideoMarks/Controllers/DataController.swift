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
        
        guard let modelURL = Bundle.main.url(forResource: "VideoMarks", withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.persistentStoreCoordinator = psc
        self.completeCallback = callback
        
        super.init()
        
        DispatchQueue.global(qos: .background).async {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let docURL = urls[urls.endIndex-1]
            // The directory the application uses to store the Core Data store file.
            let storeURL = docURL.appendingPathComponent("VideoMarksData.sqlite")
            
            let optionsDict = [NSMigratePersistentStoresAutomaticallyOption:NSNumber(value: true as Bool),NSInferMappingModelAutomaticallyOption:NSNumber(value: true as Bool)]
            
            do {
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: optionsDict)
                
                if let _ = self.completeCallback {
                    //print("core date complete!!!")
                    DispatchQueue.main.async(execute: { 
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
                
                let alertC = UIAlertController(title: NSLocalizedString("Save Error", comment: "保存失败"), message: nil, preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "确认"), style: .cancel, handler: nil)
                alertC.addAction(cancelAction)
                UIApplication.shared.keyWindow?.rootViewController?.present(alertC, animated: true, completion: nil)
            }
        }
    }
}
