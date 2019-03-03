import Cocoa

extension NSWindow: NSDraggingDestination {
    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let cv = self.contentView, let vc = cv.nextResponder as? ViewController else {
            return []
        }
        return vc.draggingEntered(sender)
    }

    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let cv = self.contentView, let vc = cv.nextResponder as? ViewController else {
            return false
        }
        return vc.performDragOperation(sender)
    }
}

class ViewController: NSViewController {
    @IBOutlet weak var textfield: NSTextField!
    @IBOutlet weak var button: NSButton!
    @IBOutlet weak var imageview: NSImageView!
    let oq = OperationQueue()
    var searching = false
    var scriptPath = ""
    
    override func viewDidLayout() {
        super.viewDidLayout()

        imageview.imageScaling = .scaleProportionallyUpOrDown

        textfield.stringValue = "Drag Here to Verify"
        
        self.view.window!.registerForDraggedTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")])
    }

    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !searching else {
            return []
        }
        return NSDragOperation.copy
    }


    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let pbis = sender.draggingPasteboard.pasteboardItems, 
           let path = pbis[0].string(forType: NSPasteboard.PasteboardType(rawValue: "public.file-url")),
           let url = URL(string: path) { 
            searching = true
            button.isEnabled = false
            if (!url.absoluteString.hasSuffix("demo.sh")) {
                textfield.stringValue = "⏳ Searching Chain...\n✅ File Hashed\n⏳ Found in Chain\n⏳ Found with QR Code\n⏳ Centsi Credits: ?"
                let im = NSImage(byReferencing: url)
                if (im.size.width > 0) {
                  imageview.image = im
                } else {
                  imageview.image = nil
                }

                oq.addOperation() {
                    let task = Process()
                    task.launchPath = "/bin/bash"
                    task.arguments = [self.scriptPath,url.path,"qr"]
                    task.launch()
                    task.waitUntilExit()
                    DispatchQueue.main.sync {
                        if task.terminationStatus == 0 {
                            self.textfield.stringValue = "\n✅ File Hashed\n✅ Found in Chain\n✅ Found with QR Code\n💳 ¢entsi Credits: 8"
                            self.searching = false
                            self.button.isEnabled = true
                            self.oq.addOperation() {
                                let task = Process()
                                task.launchPath = "/bin/bash"
                                task.arguments = [self.scriptPath,"report"]
                                task.launch()
                                task.waitUntilExit()
                             }
                        } else {
                            self.oq.addOperation() {
                                let task = Process()
                                task.launchPath = "/bin/bash"
                                task.arguments = [self.scriptPath,url.path]
                                task.launch()
                                task.waitUntilExit()
                                DispatchQueue.main.sync {
                                    if task.terminationStatus == 0 {
                                        self.textfield.stringValue = "\n✅ File Hashed\n✅ Found in Chain\n❌ Found with QR Code\n❌ ¢entsi Credits: 0"
                                    } else {
                                        self.textfield.stringValue = "\n✅ File Hashed\n❌ Found in Chain\n❌ Found with QR Code\n❌ ¢entsi Credits: 0"
                                    }
                                    self.searching = false
                                    self.button.isEnabled = true
                                    self.oq.addOperation() {
                                        let task = Process()
                                        task.launchPath = "/bin/bash"
                                        task.arguments = [self.scriptPath,"report"]
                                        task.launch()
                                        task.waitUntilExit()
                                     }
                                }
                            }
                        }
                    }
                }

            } else {
                scriptPath = url.path
                searching = false
                button.isEnabled = true
            }
            return true
        } else {
            return false
        }
    }

    @IBAction func click(_ sender: NSButton) {
        button.isEnabled = false

        textfield.stringValue = "⏳ Syncing chain..."

        oq.addOperation() {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = [self.scriptPath]
            task.launch()
            task.waitUntilExit()
            DispatchQueue.main.sync {
                if task.terminationStatus == 0 {
                    self.textfield.stringValue = "⛓  Chain updated."
                } else {
                    self.textfield.stringValue = "☠  Problem updating chain."
                }
                self.button.isEnabled = true
            }
        }
    }
}
