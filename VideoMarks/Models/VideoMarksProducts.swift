//
//  VideoMarksProducts.swift
//  VideoMarks
//
//  Created by nevercry on 7/29/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import Foundation

public enum VideoMarksProducts {
    
    private static let Prefix = "com.videomarks."
    
    
    /// MARK: - Supported Product Identifiers
    public static let RemoveAd = Prefix + "removead"
    
    private static let productIdentifiers: Set<ProductIdentifier> = [VideoMarksProducts.RemoveAd]
    
    /// Static instance of IAPHelper that for Pings products.
    public static let store = IAPHelper(productIdentifiers: VideoMarksProducts.productIdentifiers)
}

/// Return the resourcename for the product identifier.
func resourceNameForProductIdentifier(productIdentifier: String) -> String? {
    return productIdentifier.componentsSeparatedByString(".").last
}