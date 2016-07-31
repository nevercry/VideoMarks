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
    weak var viewController: UIViewController?
    
    override init() {
        
        super.init()
        
        // 设置画中画代理
        avPlayer.delegate = self
        avPlayer.allowsPictureInPicturePlayback = true
        avPlayer.modalTransitionStyle = .CrossDissolve
        
        //注册视频播放器播放完成通知
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(rePlay), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(updatePlayer), name: AVAudioSessionInterruptionNotification, object: nil)
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
        viewController = inViewController
        dispatch_async(dispatch_get_main_queue()) { [weak self] in            
            self?.avPlayer.player = player
            self?.viewController?.presentViewController(self!.avPlayer, animated: true) {
                self?.avPlayer.player?.play()
                self?.updateForPiP()
            }
        }
    }
    
    func rePlay(note: NSNotification) {
        avPlayer.player?.seekToTime(kCMTimeZero)
        avPlayer.player?.play()
    }
    
    // 修复调用Siri完毕后，音频自动播放的bug
    func updatePlayer(note: NSNotification) {
        if let userInfo = note.userInfo {
            if let interruptType = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber {
                if interruptType.unsignedIntegerValue == AVAudioSessionInterruptionType.Ended.rawValue {
                    if viewController?.view.window != nil && isInPiP == false {
                        avPlayer.player = nil
                    }
                }
            }
        }
    }
    
    func updateForPiP()  {
        if let _ = viewController?.presentationController {
            if isInPiP {
                dispatch_async(dispatch_get_main_queue()) { [weak self] in
                    self?.viewController?.dismissViewControllerAnimated(true, completion: nil)
                }
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
            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                self?.viewController?.presentViewController(playerViewController, animated: true, completion: nil)
            }
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
