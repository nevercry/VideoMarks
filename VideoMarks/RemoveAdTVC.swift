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
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    var removeAdProduct: SKProduct?
    
    lazy var networkIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
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
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 加载商品
        self.tableView.isUserInteractionEnabled = false
        
        self.networkIndicator.startAnimating()
        tableView.addSubview(self.networkIndicator)
        
        let consX = NSLayoutConstraint(item: networkIndicator, attribute: .centerX, relatedBy: .equal, toItem: tableView, attribute: .centerX, multiplier: 1.0, constant: 0)
        let consY = NSLayoutConstraint(item: networkIndicator, attribute: .centerY, relatedBy: .equal, toItem: tableView, attribute: .centerY, multiplier: 1.0, constant: 0)
        
        // 添加约束
        NSLayoutConstraint.activate([consX,consY])
        
        
        VideoMarksProducts.store.requestProductsWithCompletionHandler { (sucess, products) in
            self.networkIndicator.stopAnimating()
            if sucess {
                self.removeAdProduct = products.last
                if self.removeAdProduct != nil {
                    let numformater = NumberFormatter()
                    numformater.formatterBehavior = .behavior10_4
                    numformater.numberStyle = .currency
                    numformater.locale = self.removeAdProduct!.priceLocale
                    let formaterString = numformater.string(from: self.removeAdProduct!.price)
                    self.removeAdCell.detailTextLabel?.text = formaterString
                }
            }
            
            guard self.removeAdProduct != nil else {
                let alertController = UIAlertController(title: NSLocalizedString("Can't fetch the product.", comment: "无法获取到商品"), message: nil, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "确定"), style: .cancel, handler: { (action) in
                    self.dismiss(animated: true, completion: nil)
                }))
                
                self.present(alertController, animated: true, completion: nil)
                
                return
            }
            
            self.tableView.isUserInteractionEnabled = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(userDidPurchased), name: NSNotification.Name(rawValue: IAPHelperProductPurchasedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(failTransaction), name: NSNotification.Name(rawValue: IAPHelperFailedTransactionNotification), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.networkIndicator.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions 
    // 用户完成内购
    func userDidPurchased() {
        self.networkIndicator.stopAnimating()
        self.performSegue(withIdentifier: "unwindToVideoMarksTVC", sender: nil)
    }
    
    func failTransaction() {
        self.networkIndicator.stopAnimating()
    }
    
    // MARK: - UITableView Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if (indexPath as NSIndexPath).section == 0 {
            //MARK:  购买
            self.networkIndicator.startAnimating()
            
            guard self.removeAdProduct != nil  else { return }
            VideoMarksProducts.store.purchaseProduct(self.removeAdProduct!)
        } else if (indexPath as NSIndexPath).section == 1 {
            //MARK:  恢复购买
            self.networkIndicator.startAnimating()
            let receiptRefreshRequest = SKReceiptRefreshRequest(receiptProperties: nil)
            receiptRefreshRequest.delegate = self
            receiptRefreshRequest.start()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension RemoveAdTVC: SKRequestDelegate {
    
    func requestDidFinish(_ request: SKRequest) {
        self.userDidPurchased()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("error \(error.localizedDescription)")
        
        self.failTransaction()
    }
}
