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
    
    func youkuParse(_ data: Data) -> [NSString] {
        print("优酷解析")
        let dataInfo = String(data: data, encoding: String.Encoding.utf8)
        let scanner = Scanner(string: dataInfo!)
        
        var kf0_previousVideoURL: NSString?
        var kf0_videoFragments: [NSString] = []
        
        var kf1_previousVideoURL: NSString?
        var kf1_videoFragments: [NSString] = []
        
        while !scanner.isAtEnd {
            scanner.scanUpTo("http", into: nil)
            var videoFragmentURL: NSString?
            scanner.scanUpTo(".ts", into: &videoFragmentURL)
            guard let _ = videoFragmentURL else { break }
            
            scanner.scanUpTo("ts_keyframe", into: nil)
            scanner.scanString("ts_keyframe=", into: nil)
            
            var isKeyFrame = -1
            scanner.scanInt(&isKeyFrame)
            
            if isKeyFrame == 0 {
                if kf0_previousVideoURL == nil || !kf0_previousVideoURL!.isEqual(to: videoFragmentURL! as String) {
                    kf0_videoFragments.append(videoFragmentURL!)
                    kf0_previousVideoURL = videoFragmentURL!
                }
            } else if isKeyFrame == 1 {
                if kf1_previousVideoURL == nil || !kf1_previousVideoURL!.isEqual(to: videoFragmentURL! as String) {
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
}
