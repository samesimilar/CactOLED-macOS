//
//  ViewController.swift
//  CactOLED
//
//  Created by samesimilar on 2025-01-19.
//

import Cocoa
import WebKit
import OSCKit

class ViewController: NSViewController, WKNavigationDelegate, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        let retyped = message.body as! Dictionary<String,Any>
        let address = retyped["address"] as! String
        // some basic bottom-shelf assigning of types. If we want to handle more types, probably
        // better to add a type-annotation on the JS side. But for our app really we just expect Ints.
        let v : [any OSCValue] = (retyped["v"] as! Array<Any>).map { (val) -> (any OSCValue) in
            switch(val) {
            case let t as Int:
                return t
            case let t as Int32:
                return t
            case let t as UInt8:
                return t
            case let t as Float:
                return t
            case let t as String:
                return t
            default:
                return 0
            }
        }
        
        let msg = OSCMessage(address, values:v)
        do {
            try oscClient.send(msg, to: "127.0.0.1", port: 4000)
        } catch let e {
            print(e)
        }
        
    }
    
    func sendMessageToView(message: Any) {
        
        webView!.callAsyncJavaScript("window.oscin(message);", arguments: ["message":message],in: nil, in: WKContentWorld.page)
    
    }
    
    func handleOsc(received oscMessage: OSCMessage) throws {
        var message = [String:Any]()
        
        message["address"] = oscMessage.addressPattern.stringValue
        let v : [Any] = oscMessage.values.map { anyOSCValue -> [Any] in
            switch (anyOSCValue) {
            case let d as Data:
                let bytes = d.map { b in
                    Int(b)
                }
                return [Int(bytes.count)] + bytes
            default:
                return [anyOSCValue]
            }
        }.flatMap { $0 }
        
        message["v"] = v
        sendMessageToView(message: message)
    }
    
    @IBOutlet var webView: WKWebView!
    let oscClient = OSCClient()
    var oscServer: OSCServer!
    
    override func viewWillDisappear() {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        self.oscServer = OSCServer(port: 4002)
        
        
        let controller = WKUserContentController()
        controller.add(self, name: "host")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        
        webView = WKWebView(frame: self.view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        
        self.view.addSubview(webView)
        webView.navigationDelegate = self;
        if #available(macOS 13.3, *) {
            self.webView.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
        self.webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let url = Bundle.main.url(forResource: "index", withExtension: "html")!
        
        

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        // Do any additional setup after loading the view.
        
        oscServer.setHandler {[weak self] oscMessage, timeTag in
//            print( oscMessage.addressPattern.stringValue)
            DispatchQueue.main.async {[weak self] in
                do {
                    try self?.handleOsc(received: oscMessage)
                } catch {
                    print(error)
                }
            }

       }
        do {
            try oscServer.start()
        } catch let e {
            print(e)
        }
        

    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    override func keyDown(with event: NSEvent) {

    }

    override func keyUp(with event: NSEvent) {

    }


}

