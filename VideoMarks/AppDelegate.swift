//
//  AppDelegate.swift
//  VideoMarks
//
//  Created by nevercry on 6/5/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var dataController: DataController!
    var backgroundSessionCompletionHandler: (() -> Void)?
    
    class func shareDelegate() -> AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        print("\(launchOptions)")
        
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        print("\(launchOptions)")
                
        dataController = DataController(callback: {
            NotificationCenter.default.post(Notification(name: VideoMarksConstants.CoreDataStackCompletion))
        })
        
        let tabC = window?.rootViewController as! UITabBarController
        
        let naviC = tabC.viewControllers!.first as! UINavigationController
        
        let rootViewController = naviC.viewControllers.first! as! VideoMarksTVC
        rootViewController.dataController = dataController
        return true
    }

   
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        dataController.saveContext()
    }
    
    // MARK: - Backgourd Transfer
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        backgroundSessionCompletionHandler = completionHandler
    }
}

