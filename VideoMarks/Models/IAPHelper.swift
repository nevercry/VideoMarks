//
//  IAPHelper.swift
//  VideoMarks
//
//  Created by nevercry on 7/29/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import Foundation
import StoreKit

/// Notification that is generated when a product is purchased.
public let IAPHelperProductPurchasedNotification = "IAPHelperProductPurchasedNotification"
public let IAPHelperFailedTransactionNotification = "IAPHelperFailedTransactionNotification"

/// Product identifiers are unique strings registered on the app store.
public typealias ProductIdentifier = String

/// Completion handler called when products are fetched.
public typealias RequestProductsCompletionHandler = (_ sucess: Bool, _ products: [SKProduct]) -> ()

/// A Helper Class for In-App-Purchases, it can fetch products, tell you if a product has been purchased,
/// purchase products, and restore purchases. Use NSUserDefaults to cache if a product has been purchased.
open class IAPHelper: NSObject {
    
    /// MARK: - User facing API
    
    /// Initialize the helper. Pass in the set of ProductIdentifiers supported by the app.
    public init(productIdentifiers: Set<ProductIdentifier>) {
        self.productIdentifiers = productIdentifiers

        super.init()
        
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    /// Gets the list of SKProducts from the Apple server calls the handler with the list of products.
    open  func requestProductsWithCompletionHandler(_ hanlder: @escaping RequestProductsCompletionHandler) {
        completionHandler = hanlder
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    /// Initiates purchase of a product.
    open func purchaseProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    /// If the state of whether purchases have been made if lost (e.g. the
    /// user deletes and reinsatlls the app) this will recover the purchase.
    open func restoreCompletedTransactions() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    open class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    /// MARK: - Private Properties
    
    // Used to keep track of the possible products and which ones have been purchased.
    fileprivate let productIdentifiers: Set<ProductIdentifier>
    
    /// Used by SKProductsRequestDelegate
    fileprivate var productsRequest: SKProductsRequest?
    fileprivate var completionHandler: RequestProductsCompletionHandler?
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        print("Load list of products...")
        let products = response.products
        completionHandler?(true, products)
        clearRequest()
        
        // debug printing
        for p in products {
            print("Found product: \(p.productIdentifier) \(p.localizedDescription) \(p.price.floatValue)")
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products.")
        print("Error: \(error)")
        completionHandler?(false, [])
        clearRequest()
    }
    
    fileprivate func clearRequest() {
        productsRequest = nil
        completionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {
    
    /// This is a function called by the payment queue, not to be called directly.
    /// For each transaction act accordingly, save in the purchased cache, issue notifications,
    /// mark the transaction as complete.
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                completeTransaction(transaction)
            case .failed:
                failedTransaction(transaction)
            case .restored:
                restoreTransaction(transaction)
            case .deferred:
                break
            case .purchasing:
                break
            }
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("restore error \(error)")
        NotificationCenter.default.post(name: Notification.Name(rawValue: IAPHelperFailedTransactionNotification), object: nil)
        
        for transaction in queue.transactions {
            print("transaction is \(transaction)")
            
            SKPaymentQueue.default().finishTransaction(transaction)
        }
        
    }
    
    fileprivate func completeTransaction(_ transaction: SKPaymentTransaction) {
        print("completeTransaction...")
        provideContentForProductIdentifier(transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    fileprivate func restoreTransaction(_ transaction: SKPaymentTransaction) {
        let productIdentifier = transaction.original!.payment.productIdentifier
        print("restoreTransaction... \(productIdentifier)")
        provideContentForProductIdentifier(productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    
    // Helper: Saves the fact that the product has been purchased and posts a notification.
    fileprivate func provideContentForProductIdentifier(_ productIdentifier: String) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: IAPHelperProductPurchasedNotification), object: productIdentifier)
    }
    
    fileprivate func failedTransaction(_ transaction: SKPaymentTransaction) {
        print("failedTransaction...")
        if let errorcode = transaction.error?._code {
            if errorcode != SKError.paymentCancelled.rawValue {
                print("Transaction error: \(transaction.error!.localizedDescription)")
                NotificationCenter.default.post(name: Notification.Name(rawValue: IAPHelperFailedTransactionNotification), object: nil)
            }
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    
}
