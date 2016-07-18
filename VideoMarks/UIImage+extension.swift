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
    class func alphaSafariIcon(width: Float, scale: Float) -> UIImage {
        let halfWidth = width / 2.0
        let triangleTipToCircleGap = ceilf(0.012 * width)
        let triangleBaseHalfWidth = ceilf(0.125 * width) / 2.0
        let tickMarkToCircleGap = ceilf(0.0325 * width)
        let tickMarkLengthLong = ceilf(0.08 * width);
        let tickMarkLengthShort = ceilf(0.045 * width)
        let tickMarkWidth = 1.0 / scale
        let tickMarkHalfWidth = tickMarkWidth / 2.0
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(CGFloat(width), CGFloat(width)), false, CGFloat(scale));
        let context = UIGraphicsGetCurrentContext()
        
        // Outer circle with gradient fill
        let colors: [CGFloat] = [
            CGFloat(0.0), CGFloat(0.0), CGFloat(0.0), CGFloat(0.25),
            CGFloat(0.0), CGFloat(0.0), CGFloat(0.0), CGFloat(0.50)]
        
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradientCreateWithColorComponents(baseSpace, colors, nil, 2)
        CGContextSaveGState(context)
        CGContextAddEllipseInRect(context, CGRectMake(0, 0, CGFloat(width), CGFloat(width)))
        CGContextClip(context)
        CGContextDrawLinearGradient(context, gradient, CGPointMake(CGFloat(halfWidth), 0), CGPointMake(CGFloat(halfWidth), CGFloat(width)), .DrawsBeforeStartLocation)
        CGContextRestoreGState(context)
        
        // Tick lines around the circle
        UIColor(white: 0.0, alpha: 0.5).setStroke()
        let numTickLines = 72
        for i in 0 ..< numTickLines {
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, .Clear);
            CGContextTranslateCTM(context, CGFloat(halfWidth), CGFloat(halfWidth));
            CGContextRotateCTM(context, CGFloat(2 * Float(M_PI) * ( Float(i) / Float(numTickLines))));
            CGContextTranslateCTM(context, -CGFloat(halfWidth), -CGFloat(halfWidth));
            
            let tickLine = UIBezierPath()
            tickLine.moveToPoint(CGPointMake(CGFloat(halfWidth - tickMarkHalfWidth), CGFloat(tickMarkToCircleGap)))
            tickLine.addLineToPoint(CGPointMake(CGFloat(halfWidth - tickMarkHalfWidth), CGFloat(tickMarkToCircleGap + (i % 2 == 1 ? tickMarkLengthShort : tickMarkLengthLong))))
            tickLine.lineWidth = CGFloat(tickMarkWidth)
            tickLine.stroke()
            CGContextRestoreGState(context)
        }
        
        // "Needle" triangles
        CGContextSaveGState(context);
        
        CGContextTranslateCTM(context, CGFloat(halfWidth), CGFloat(halfWidth))
        CGContextRotateCTM(context, CGFloat(M_PI + M_PI_4));
        CGContextTranslateCTM(context, -CGFloat(halfWidth), -CGFloat(halfWidth))
        UIColor.blackColor().setFill()
        let topTriangle = UIBezierPath()
        topTriangle.moveToPoint(CGPointMake(CGFloat(halfWidth), CGFloat(triangleTipToCircleGap)))
        topTriangle.addLineToPoint(CGPointMake(CGFloat(halfWidth - triangleBaseHalfWidth), CGFloat(halfWidth)))
        topTriangle.addLineToPoint(CGPointMake(CGFloat(halfWidth + triangleBaseHalfWidth), CGFloat(halfWidth)))
        topTriangle.closePath()
        CGContextSetBlendMode(context, .Clear)
        topTriangle.fill()
        
        let bottomTriangle = UIBezierPath()
        bottomTriangle.moveToPoint(CGPointMake(CGFloat(halfWidth), CGFloat(width - triangleTipToCircleGap)))
        bottomTriangle.addLineToPoint(CGPointMake(CGFloat(halfWidth - triangleBaseHalfWidth), CGFloat(halfWidth)))
        bottomTriangle.addLineToPoint(CGPointMake(CGFloat(halfWidth + triangleBaseHalfWidth), CGFloat(halfWidth)))
        bottomTriangle.closePath()
        CGContextSetBlendMode(context, .Normal);
        bottomTriangle.fill()
        
        CGContextRestoreGState(context);
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return finalImage;
    }
    
    // MARK: - 根据宽高比截取图片中心并压缩
    
    /**
     根据宽高比截取图片中心
     
     - parameter ratio:              截取的宽高比
     - parameter compressionQuality: 压缩比 取值范围 0.0 到 1.0 之间
     
     - returns: 截取压缩之后的图片
     */
    func clipAndCompress(ratio: CGFloat, compressionQuality: CGFloat) -> UIImage {
        
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
        
        let clipImageSize = CGSizeMake(clipImageWidth, clipImageHeight)
        UIGraphicsBeginImageContextWithOptions(clipImageSize, false, 0.0)
        
        self.drawAtPoint(CGPointMake(imageDrawOrgin_X, imageDrawOrgin_Y))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let comressImage = UIImage(data: UIImageJPEGRepresentation(newImage, compressionQuality)!)
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
        self.drawAtPoint(CGPointMake(0, -orginY))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    
    class func resize(image: UIImage, newSize: CGSize) -> UIImage {
        //UIGraphicsBeginImageContext(newSize);
        // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
        // Pass 1.0 to force exact pixel size.
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.drawInRect(CGRectMake(0, 0, newSize.width, newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
    }
}