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
        avPlayer.modalTransitionStyle = .crossDissolve
        
        //注册视频播放器播放完成通知
        NotificationCenter.default.addObserver(self, selector: #selector(rePlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlayer), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class var sharedInstance: PlayerController {
        struct Static {
            static let instance : PlayerController = PlayerController()
        }
        return Static.instance
    }
    
    // MARK: - 播放视频
    func playVideo(_ player: AVPlayer, inViewController: UIViewController) {
        player.allowsExternalPlayback = true
        player.actionAtItemEnd = .none
        viewController = inViewController
        DispatchQueue.main.async { [weak self] in            
            self?.avPlayer.player = player
            self?.viewController?.present(self!.avPlayer, animated: true) {
                self?.avPlayer.player?.play()
                self?.updateForPiP()
            }
        }
    }
    
    @objc func rePlay(_ note: Notification) {
        avPlayer.player?.seek(to: CMTime.zero)
        avPlayer.player?.play()
    }
    
    // 修复调用Siri完毕后，音频自动播放的bug
    @objc func updatePlayer(_ note: Notification) {
        if let userInfo = (note as NSNotification).userInfo {
            if let interruptType = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber {
                if interruptType.uintValue == AVAudioSession.InterruptionType.ended.rawValue {
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
                DispatchQueue.main.async { [weak self] in
                    self?.viewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
}

extension PlayerController: AVPlayerViewControllerDelegate {
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        print("playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart")
        return true
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        print("restoreUserInterfaceForPictureInPictureStopWithCompletionHandler")
        if let _ = self.viewController?.presentedViewController {
            
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.viewController?.present(playerViewController, animated: true, completion: nil)
            }
        }
        
        completionHandler(true)
    }
    
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("WillStartPictureInPicture(")
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("DidStartPictureInPicture")
        isInPiP = true
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("WillStopPictureInP")
        isInPiP = false
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("DidStopPictureInP")
    }
}
