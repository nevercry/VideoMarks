//
//  PlayerController.swift
//  VideoMarks
//
//  Created by nevercry on 7/14/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class PlayerController: NSObject {
    let avPlayer = AVPlayerViewController()
    var isInPiP = false
    var viewController: UIViewController?
    
    override init() {
        
        super.init()
        
        // 设置画中画代理
        avPlayer.delegate = self
        avPlayer.allowsPictureInPicturePlayback = true
        avPlayer.modalTransitionStyle = .CrossDissolve
        
        //注册视频播放器播放完成通知
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(rePlay), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(updateForPiP), name: AVPlayerItemNewAccessLogEntryNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    class var sharedInstance: PlayerController {
        struct Static {
            static let instance : PlayerController = PlayerController()
        }
        return Static.instance
    }
    
    // MARK: - 播放视频
    func playVideo(player: AVPlayer, inViewController: UIViewController) {
        player.actionAtItemEnd = .None
        avPlayer.modalTransitionStyle = .CrossDissolve
        avPlayer.player = player
        viewController = inViewController
        
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.viewController?.presentViewController(self!.avPlayer, animated: true) {
                self?.avPlayer.player?.play()
            }
        }
    }
    
    func rePlay() {
        avPlayer.player?.seekToTime(kCMTimeZero)
        avPlayer.player?.play()
    }
    
    func updateForPiP()  {
        if let _ = viewController?.presentationController {
            if isInPiP {
                viewController?.dismissViewControllerAnimated(true, completion: nil)
            }
        }
    }
}

extension PlayerController: AVPlayerViewControllerDelegate {
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(playerViewController: AVPlayerViewController) -> Bool {
        print("playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart")
        return true
    }
    
    func playerViewController(playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: (Bool) -> Void) {
        print("restoreUserInterfaceForPictureInPictureStopWithCompletionHandler")
        if let _ = self.viewController?.presentedViewController {
            
        } else {
            self.viewController?.presentViewController(playerViewController, animated: true, completion: nil)
        }
        
        completionHandler(true)
    }
    
    func playerViewControllerWillStartPictureInPicture(playerViewController: AVPlayerViewController) {
        print("WillStartPictureInPicture(")
    }
    
    func playerViewControllerDidStartPictureInPicture(playerViewController: AVPlayerViewController) {
        print("DidStartPictureInPicture")
        isInPiP = true
    }
    
    func playerViewControllerWillStopPictureInPicture(playerViewController: AVPlayerViewController) {
        print("WillStopPictureInP")
        isInPiP = false
    }
    
    func playerViewControllerDidStopPictureInPicture(playerViewController: AVPlayerViewController) {
        print("DidStopPictureInP")
    }
}

