//
//  RemoveAdTVC.swift
//  VideoMarks
//
//  Created by nevercry on 7/29/16.
//  Copyright © 2016 nevercry. All rights reserved.
//

import UIKit
import StoreKit

class RemoveAdTVC: UITableViewController {
    
    @IBOutlet weak var removeAdCell: UITableViewCell!
    
    @IBOutlet weak var restorePurchaseCell: UITableViewCell!
    
    @IBAction func done(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    var removeAdProduct: SKProduct?
    
    lazy var networkIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Remove Ad", comment: "去广告")
        
        removeAdCell.textLabel?.text = NSLocalizedString("Remove Ad", comment: "去广告")
        restorePurchaseCell.textLabel?.text = NSLocalizedString("Restore Purchase", comment: "恢复购买")
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // 加载商品
        self.tableView.userInteractionEnabled = false
        
        self.networkIndicator.startAnimating()
        tableView.addSubview(self.networkIndicator)
        
        let consX = NSLayoutConstraint(item: networkIndicator, attribute: .CenterX, relatedBy: .Equal, toItem: tableView, attribute: .CenterX, multiplier: 1.0, constant: 0)
        let consY = NSLayoutConstraint(item: networkIndicator, attribute: .CenterY, relatedBy: .Equal, toItem: tableView, attribute: .CenterY, multiplier: 1.0, constant: 0)
        
        // 添加约束
        NSLayoutConstraint.activateConstraints([consX,consY])
        
        
        VideoMarksProducts.store.requestProductsWithCompletionHandler { (sucess, products) in
            self.networkIndicator.stopAnimating()
            if sucess {
                self.removeAdProduct = products.last
                if self.removeAdProduct != nil {
                    let numformater = NSNumberFormatter()
                    numformater.formatterBehavior = .Behavior10_4
                    numformater.numberStyle = .CurrencyStyle
                    numformater.locale = self.removeAdProduct!.priceLocale
                    let formaterString = numformater.stringFromNumber(self.removeAdProduct!.price)
                    self.removeAdCell.detailTextLabel?.text = formaterString
                }
            }
            
            guard self.removeAdProduct != nil else {
                let alertController = UIAlertController(title: NSLocalizedString("Can't fetch the product.", comment: "无法获取到商品"), message: nil, preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "确定"), style: .Cancel, handler: { (action) in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }))
                
                self.presentViewController(alertController, animated: true, completion: nil)
                
                return
            }
            
            self.tableView.userInteractionEnabled = true
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(userDidPurchased), name: IAPHelperProductPurchasedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(failTransaction), name: IAPHelperFailedTransactionNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.networkIndicator.removeFromSuperview()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Actions 
    // 用户完成内购
    func userDidPurchased() {
        self.networkIndicator.stopAnimating()
        self.performSegueWithIdentifier("unwindToVideoMarksTVC", sender: nil)
    }
    
    func failTransaction() {
        self.networkIndicator.stopAnimating()
    }
    
    // MARK: - UITableView Delegate
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.section == 0 {
            //MARK:  购买
            self.networkIndicator.startAnimating()
            
            guard self.removeAdProduct != nil  else { return }
            VideoMarksProducts.store.purchaseProduct(self.removeAdProduct!)
        } else if indexPath.section == 1 {
            //MARK:  恢复购买
            self.networkIndicator.startAnimating()
            let receiptRefreshRequest = SKReceiptRefreshRequest(receiptProperties: nil)
            receiptRefreshRequest.delegate = self
            receiptRefreshRequest.start()
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

extension RemoveAdTVC: SKRequestDelegate {
    
    func requestDidFinish(request: SKRequest) {
        self.userDidPurchased()
    }
    
    func request(request: SKRequest, didFailWithError error: NSError) {
        print("error \(error.localizedDescription)")
        
        self.failTransaction()
    }
}