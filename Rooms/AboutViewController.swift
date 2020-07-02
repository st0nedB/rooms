//
//  CreditViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 08.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    //
    @IBOutlet weak var aboutTextView: UITextView!
    @IBOutlet weak var creditTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        aboutTextView.isEditable = false
        aboutTextView.isSelectable = true
        creditTextView.isEditable = false
        creditTextView.isSelectable = true
        
        let textAboutString = """
            Using this App, your device can localize itsself in your apartment/house using iBeacon technology. To configure it, set iBeacons in the Settings tab, record training data for each room.
            To interact with your home automation system, it provides an MQTT interface to report its current location. Just configure your desired broker in the settings tab.
            Please be noted, the app is designed for improved battery efficiency, but it will have an impact on your battery life. Future updates will work on increasing efficency further.
        """
        
        let aboutText = NSMutableAttributedString(string: textAboutString)
        
        aboutTextView.attributedText = aboutText
        
        
        
        let textCreditString = """
            This App uses the following resources:
            \u{2022} Moscapsule, an awesome library for MQTT
            \u{2022} IQKeyboardManager, a true-life saver to avoid unnecessary UIScrollViews
            \u{2022} Icons from www.icons8.com
            \u{2002} This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit (http://www.openssl.org/)
        """
        
        let textCredit = NSMutableAttributedString(string: textCreditString)
        textCredit.addAttribute(.link, value: "https://github.com/flightonary/Moscapsule", range: (textCreditString as NSString).range(of: "Moscapsule, an awesome library for MQTT"))
        textCredit.addAttribute(.link, value: "https://github.com/hackiftekhar/IQKeyboardManager", range: (textCreditString as NSString).range(of: "IQKeyboardManager, a true-life saver to avoid unnecessary UIScrollViews"))
        textCredit.addAttribute(.link, value: "https://icons8.com", range: (textCreditString as NSString).range(of: "Icons from www.icons8.com"))
        textCredit.addAttribute(.link, value: "http://www.openssl.org/", range: (textCreditString as NSString).range(of: "http://www.openssl.org/"))
        
        creditTextView.attributedText = textCredit
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }
    
    
}
