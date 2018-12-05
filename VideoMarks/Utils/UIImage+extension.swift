//
//  UIImage+extension.swift
//  VideoMarks
//
//  Created by nevercry on 7/13/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit

extension UIImage {
    // 创建Safari 视图
    class func alphaSafariIcon(_ width: Float, scale: Float) -> UIImage {
        let halfWidth = width / 2.0
        let triangleTipToCircleGap = ceilf(0.012 * width)
        let triangleBaseHalfWidth = ceilf(0.125 * width) / 2.0
        let tickMarkToCircleGap = ceilf(0.0325 * width)
        let tickMarkLengthLong = ceilf(0.08 * width);
        let tickMarkLengthShort = ceilf(0.045 * width)
        let tickMarkWidth = 1.0 / scale
        let tickMarkHalfWidth = tickMarkWidth / 2.0
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: CGFloat(width), height: CGFloat(width)), false, CGFloat(scale));
        let context = UIGraphicsGetCurrentContext()
        
        // Outer circle with gradient fill
        let colors: [CGFloat] = [
            CGFloat(0.0), CGFloat(0.0), CGFloat(0.0), CGFloat(0.25),
            CGFloat(0.0), CGFloat(0.0), CGFloat(0.0), CGFloat(0.50)]
        
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorSpace: baseSpace, colorComponents: colors, locations: nil, count: 2)
        context!.saveGState()
        context!.addEllipse(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(width)))
        context!.clip()
        context!.drawLinearGradient(gradient!, start: CGPoint(x: CGFloat(halfWidth), y: 0), end: CGPoint(x: CGFloat(halfWidth), y: CGFloat(width)), options: .drawsBeforeStartLocation)
        context!.restoreGState()
        
        // Tick lines around the circle
        UIColor(white: 0.0, alpha: 0.5).setStroke()
        let numTickLines = 72
        for i in 0 ..< numTickLines {
            context!.saveGState();
            context!.setBlendMode(.clear);
            context!.translateBy(x: CGFloat(halfWidth), y: CGFloat(halfWidth));
            context!.rotate(by: CGFloat(2 * Float.pi * ( Float(i) / Float(numTickLines))));
            context!.translateBy(x: -CGFloat(halfWidth), y: -CGFloat(halfWidth));
            
            let tickLine = UIBezierPath()
            tickLine.move(to: CGPoint(x: CGFloat(halfWidth - tickMarkHalfWidth), y: CGFloat(tickMarkToCircleGap)))
            tickLine.addLine(to: CGPoint(x: CGFloat(halfWidth - tickMarkHalfWidth), y: CGFloat(tickMarkToCircleGap + (i % 2 == 1 ? tickMarkLengthShort : tickMarkLengthLong))))
            tickLine.lineWidth = CGFloat(tickMarkWidth)
            tickLine.stroke()
            context!.restoreGState()
        }
        
        // "Needle" triangles
        context!.saveGState();
        
        context!.translateBy(x: CGFloat(halfWidth), y: CGFloat(halfWidth))
        context!.rotate(by: CGFloat(Float.pi + Float.pi/4));
        context!.translateBy(x: -CGFloat(halfWidth), y: -CGFloat(halfWidth))
        UIColor.black.setFill()
        let topTriangle = UIBezierPath()
        topTriangle.move(to: CGPoint(x: CGFloat(halfWidth), y: CGFloat(triangleTipToCircleGap)))
        topTriangle.addLine(to: CGPoint(x: CGFloat(halfWidth - triangleBaseHalfWidth), y: CGFloat(halfWidth)))
        topTriangle.addLine(to: CGPoint(x: CGFloat(halfWidth + triangleBaseHalfWidth), y: CGFloat(halfWidth)))
        topTriangle.close()
        context!.setBlendMode(.clear)
        topTriangle.fill()
        
        let bottomTriangle = UIBezierPath()
        bottomTriangle.move(to: CGPoint(x: CGFloat(halfWidth), y: CGFloat(width - triangleTipToCircleGap)))
        bottomTriangle.addLine(to: CGPoint(x: CGFloat(halfWidth - triangleBaseHalfWidth), y: CGFloat(halfWidth)))
        bottomTriangle.addLine(to: CGPoint(x: CGFloat(halfWidth + triangleBaseHalfWidth), y: CGFloat(halfWidth)))
        bottomTriangle.close()
        context!.setBlendMode(.normal);
        bottomTriangle.fill()
        
        context!.restoreGState();
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return finalImage!;
    }
    
    // MARK: - 根据宽高比截取图片中心并压缩
    
    /**
     根据宽高比截取图片中心
     
     - parameter ratio:              截取的宽高比
     - parameter compressionQuality: 压缩比 取值范围 0.0 到 1.0 之间
     
     - returns: 截取压缩之后的图片
     */
    func clipAndCompress(_ ratio: CGFloat, compressionQuality: CGFloat) -> UIImage {
        
        let height = self.size.height
        let width = self.size.width
        
        var clipImageWidth, clipImageHeight:CGFloat
        var imageDrawOrgin_X, imageDrawOrgin_Y:CGFloat
        
        if (width/height < 1) {
            clipImageWidth = width
            clipImageHeight = clipImageWidth/ratio
            
            imageDrawOrgin_X = 0
            imageDrawOrgin_Y = -(height-clipImageHeight)/2
        } else if (width/height > 1) {
            clipImageHeight = height
            clipImageWidth = clipImageHeight*ratio
            
            imageDrawOrgin_X = -(width - clipImageWidth)/2
            imageDrawOrgin_Y = 0
        } else {
            clipImageWidth = width
            clipImageHeight = clipImageWidth/ratio
            
            imageDrawOrgin_X = 0
            imageDrawOrgin_Y = 0
        }
        
        let clipImageSize = CGSize(width: clipImageWidth, height: clipImageHeight)
        UIGraphicsBeginImageContextWithOptions(clipImageSize, false, 0.0)
        
        self.draw(at: CGPoint(x: imageDrawOrgin_X, y: imageDrawOrgin_Y))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let comressImage = UIImage(data: newImage!.jpegData(compressionQuality: compressionQuality)!)
        return comressImage!
    }
    
    func crop16_9() -> UIImage {
        let height = self.size.height
        let width = self.size.width
        
        // width 不变 取 height
        let cropHeight = 9/16 * width
        
        // 确定orginY 
        let orginY = (height - cropHeight)/2
        
        // 开始截取图片
        let clipImageSize = CGSize(width: width, height: cropHeight)
        UIGraphicsBeginImageContextWithOptions(clipImageSize, false, 0.0)
        self.draw(at: CGPoint(x: 0, y: -orginY))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    
    class func resize(_ image: UIImage, newSize: CGSize) -> UIImage {
        //UIGraphicsBeginImageContext(newSize);
        // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
        // Pass 1.0 to force exact pixel size.
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage!;
    }
}
