struct Credits: Codable {
    var credits:[Credit]
}

struct Credit: Codable {
    var key:String
    var tok:String
    var amt:Float
    var txt:String
}

typealias bh = BlackHatDemoPlugin

@objc(BlackHatDemoPlugin) class BlackHatDemoPlugin: CDVPlugin {
  static var sha512 = Digest(algorithm: .sha512)
  static var encoder = JSONEncoder()
  static var decoder = JSONDecoder()

  @objc(start:) func start(cmd: CDVInvokedUrlCommand) -> Void {
    bh.encoder.outputFormatting = [JSONEncoder.OutputFormatting.prettyPrinted]
    let res = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Plugin initialized.")
    self.commandDelegate!.send(res, callbackId: cmd.callbackId)
  }

  @objc(getCredits:) func getCredits(cmd: CDVInvokedUrlCommand) -> Void {
    DispatchQueue.global(qos: .background).async {
      guard let docsURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Couldn't get path to document folder.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }
      let creditsURL = docsURL.appendingPathComponent("credits").appendingPathExtension("json") 

      let json = (try? String(contentsOf: creditsURL)) ?? #"{"credits": []}"#

      let res = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
      self.commandDelegate!.send(res, callbackId: cmd.callbackId)
    }
  }

  @objc(submitCredit:) func submitCredit(cmd: CDVInvokedUrlCommand) -> Void {
    DispatchQueue.global(qos: .background).async {

      guard let docsURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Couldn't get path to document folder.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      let creditsURL = docsURL.appendingPathComponent("credits").appendingPathExtension("json") 
      let creditsJSON = (try? String(contentsOf: creditsURL)) ?? #"{"credits": []}"#

      guard var credits = try? bh.decoder.decode(Credits.self, from: creditsJSON.data(using: .utf8)!) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem decoding credits.json.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      guard let inJSON = cmd.argument(at:0) as? String,
            var credit = try? bh.decoder.decode(Credit.self, from: inJSON.data(using: .utf8)!) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem decoding credit.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      let sec = BChain.createSecretKey()
      guard let pub = try? BChain.createPublicKey(fromSecretKey: sec),
            let hash = try? bh.sha512.hash(pub).hexEncodedString() else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem generating public key.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      let keysURL = docsURL.appendingPathComponent("keys", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: keysURL, withIntermediateDirectories: true)
      } catch {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem creating keys directory: \(error).")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }
      let keyURL = keysURL.appendingPathComponent(hash)

      do {
        try sec.write(to: keyURL)
      } catch {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem writing key: \(error).")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      credit.key = hash

      guard let creditData = try? bh.encoder.encode(credit),
            let creditHash = try? bh.sha512.hash(creditData),
            let outJSON = String(data: creditData, encoding: .utf8) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem encoding credit.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      let subsURL = docsURL.appendingPathComponent("submissions", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: subsURL, withIntermediateDirectories: true)
      } catch {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem creating submissions directory: \(error).")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }
      let subURL = subsURL.appendingPathComponent(creditHash.hexEncodedString())

      do {
        if credit.tok == "" {
          _ = try outJSON.write(to: subURL, atomically: true, encoding: .utf8)
        }
      } catch {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem writing submission: \(error).")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      var subValue = creditHash
      if credit.tok != "" {
        let tok = credit.tok
        var tokHash = Data(capacity: 64)
        var a = tok.startIndex
        while (a < tok.endIndex) {
          let b = tok.index(a, offsetBy: 2)
          tokHash.append(UInt8(tok[a..<b], radix: 16) ?? 0)
          a = b
        }
        subValue = tokHash
      }

      let masterURL = docsURL.appendingPathComponent("master").appendingPathExtension("sec") 
      var grantor = try? Data(contentsOf: masterURL) 
      if (grantor == nil) {
        grantor = BChain.createSecretKey()
        do {
          try grantor!.write(to: masterURL)
        } catch {
          let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem writing master key: \(error).")
          self.commandDelegate!.send(res, callbackId: cmd.callbackId)
          return
        }
      }

      guard let grantorPub = try? BChain.createPublicKey(fromSecretKey: grantor!),
            let grantorHash = try? bh.sha512.hash(grantorPub) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem creating hash of public master.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      var value = Data(capacity: 128)
      value.append(grantorHash)
      value.append(subValue)

      guard let valueHash = try? bh.sha512.hash(value) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem hashing value.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      var sig = Data(capacity: 4352)
      sig.append(grantorHash)
      sig.append(subValue)

      guard let subSig = try? BChain.sign(valueHash, secretKey: sec) else {
        let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem signing value.")
        self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        return
      }

      print(grantorHash.count)
      print(subValue.count)
      print(subSig.count)

      sig.append(subSig)

      var req = URLRequest(url: URL(string: "https://u8w9cposi2.execute-api.us-east-2.amazonaws.com/demo/observations")!)
      req.httpMethod = "POST"
      req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
      req.httpBody = sig

      let task = URLSession.shared.dataTask(with: req) { data, response, error in
        if (error != nil) {
          let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Chain error: \(error!)")
          self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        } else {
          print("Chain response: \(String(data: data!, encoding: .utf8)!)")

          credits.credits.append(credit)

          guard let newJSON = try? bh.encoder.encode(credits),
                let newStr = String(data: newJSON, encoding: .utf8) else {
            let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem encoding credits.")
            self.commandDelegate!.send(res, callbackId: cmd.callbackId)
            return
          }

          do {
            _ = try newStr.write(to: creditsURL, atomically: true, encoding: .utf8)
          } catch {
            let res = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Problem writing credits: \(error).")
            self.commandDelegate!.send(res, callbackId: cmd.callbackId)
            return
          }

          let res = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: outJSON)
          self.commandDelegate!.send(res, callbackId: cmd.callbackId)
        }

        return

      }
      task.resume()
    }
  }

}
