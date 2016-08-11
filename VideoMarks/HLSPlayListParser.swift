//
//  HLSPlayListParser.swift
//  VideoMarks
//
//  Created by nevercry on 8/11/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

class HLSPlayListParser {
    static let shareInstance = HLSPlayListParser()
    
    func youkuParse(data: NSData) -> [NSString] {
        print("优酷解析")
        let dataInfo = String(data: data, encoding: NSUTF8StringEncoding)
        let scanner = NSScanner(string: dataInfo!)
        
        var kf0_previousVideoURL: NSString?
        var kf0_videoFragments: [NSString] = []
        
        var kf1_previousVideoURL: NSString?
        var kf1_videoFragments: [NSString] = []
        
        while !scanner.atEnd {
            scanner.scanUpToString("http", intoString: nil)
            var videoFragmentURL: NSString?
            scanner.scanUpToString(".ts", intoString: &videoFragmentURL)
            guard let _ = videoFragmentURL else { break }
            
            scanner.scanUpToString("ts_keyframe", intoString: nil)
            scanner.scanString("ts_keyframe=", intoString: nil)
            
            var isKeyFrame = -1
            scanner.scanInteger(&isKeyFrame)
            
            if isKeyFrame == 0 {
                if kf0_previousVideoURL == nil || !kf0_previousVideoURL!.isEqualToString(videoFragmentURL as! String) {
                    kf0_videoFragments.append(videoFragmentURL!)
                    kf0_previousVideoURL = videoFragmentURL!
                }
            } else if isKeyFrame == 1 {
                if kf1_previousVideoURL == nil || !kf1_previousVideoURL!.isEqualToString(videoFragmentURL as! String) {
                    kf1_videoFragments.append(videoFragmentURL!)
                    kf1_previousVideoURL = videoFragmentURL!
                }
            }
        }
        
        // 有两帧只取关键帧，否则取其一
        var videoFragments: [NSString]
        if kf1_videoFragments.count > 0 {
            videoFragments = kf1_videoFragments
        } else {
            videoFragments = kf0_videoFragments
        }
        
        print("the videoFragments is \(videoFragments)")
        
        return videoFragments
    }
    
    func otherParse(data: NSData) -> [NSString] {
        print("其他网站解析")
        
        let dataInfo = String(data: data, encoding: NSUTF8StringEncoding)
        let scanner = NSScanner(string: dataInfo!)
        
        var videoFragments: [NSString] = []
        var previousURL: NSString?
        while !scanner.atEnd {
            scanner.scanUpToString("http", intoString: nil)
            var videoFragmentURL: NSString?
            scanner.scanUpToString(".ts", intoString: &videoFragmentURL)
            guard let _ = videoFragmentURL else { break }
            
            if previousURL == nil || !previousURL!.isEqualToString(videoFragmentURL as! String) {
                videoFragments.append(videoFragmentURL!)
                previousURL = videoFragmentURL!
            }
        }
        
        print("the videoFragments is \(videoFragments)")
        
        return videoFragments        
    }
}
