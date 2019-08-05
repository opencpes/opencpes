import Foundation
import Glibc
import Crypto
import BChain
import SQS

func respond(body: String, status: Int) -> Void {
  let respDic = [
    "statusCode": status,
    "headers": [
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Credentials": true,
      "Content-Type": "application/json"
    ],
    "body": body
  ] as [String:Any]
  let respJSON = (try? JSONSerialization.data(withJSONObject: respDic, options: [JSONSerialization.WritingOptions.prettyPrinted])) ?? Data((#"{"status":500, "error":"Problem JSON encoding response."}"#).utf8)
  let resp = String(bytes: respJSON, encoding: .utf8) ?? #"{"status": 500, "error": "Problem stringifying response."}"#
  let rspFile = fopen("/tmp/rsp", "w")
  defer {fclose(rspFile)}
  let bytes = Array(resp.utf8)
  fwrite(bytes, 1, bytes.count, rspFile)
}

func err(_ msg: String) -> Void {
  fputs("\(msg)\n", stderr)
  respond(body: #"{"msg": "\#(msg)", "status": 500}"#, status: 500)
}

func generatePrefix() -> Data {
  var data = Data(capacity: 64)
  for _ in 0..<64 {
    data.append(UInt8.random(in: 0...255))
  }
  return data
}

let sha512 = Digest(algorithm: .sha512)
let encoder = JSONEncoder()
encoder.outputFormatting = [JSONEncoder.OutputFormatting.prettyPrinted,JSONEncoder.OutputFormatting.sortedKeys]
let sqs = SQS()
let messageGroupId = "demo"

reqLoop: while true {
  guard let reqFileData = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/req")),
        let reqParsed = try? JSONSerialization.jsonObject(with: reqFileData, options: []),
        let reqDict = reqParsed as? [String:Any],
        let reqBody = reqDict["body"] as? String,
        let reqData = Data(base64Encoded: reqBody),
        let reqContextDict = reqDict["requestContext"] as? [String:Any],
        let reqTimeMs = reqContextDict["requestTimeEpoch"] as? Int else {
    err("Problem parsing request.")
    continue reqLoop
  }
  let reqTime = reqTimeMs / 1000

  guard let queueUrl = ProcessInfo.processInfo.environment["QUEUEURL"] else {
    err("Lambda missing queueUrl configuration.")
    continue reqLoop
  }

  switch reqData.count {
    case 64:
      let prefix = generatePrefix() 
      var data = Data(prefix)
      data.append(reqData)
      guard let value = try? sha512.hash(data) else {
        err("Problem masking data.")
        continue reqLoop
      }
      let observation = Observation(prefix: prefix.hexEncodedString(),
                                    timestamp: reqTime,
                                    grantor: "",
                                    key: "",
                                    value: value.hexEncodedString())
      guard let obsData = try? encoder.encode(observation),
            let obsJSON = String(data: obsData, encoding: .utf8) else {
        err("Problem encoding observation.")
        continue reqLoop
      }

      let msg = SQS.SendMessageRequest(delaySeconds: 0, messageAttributes: [:], messageBody: obsJSON, messageDeduplicationId: nil, messageGroupId: "test", queueUrl: queueUrl)

      do {
        _ = try sqs.sendMessage(msg).wait()
      } catch {
        err("\(error)")
        continue reqLoop
      }

      respond(body: #"{"status": 200, "msg": "OK"}"#, status: 200)
      continue reqLoop

    case 4352:
      let prefix = generatePrefix()
      let pub = (try? BChain.createPublicKey(fromSignature: reqData[128..<4352], value: sha512.hash(reqData[0..<128]))) ?? Data(count: 4224)
      let keyHash = (try? sha512.hash(pub)) ?? Data(count: 64)
      var key = Data(prefix)
      key.append(keyHash)
      let maskedKey = (try? sha512.hash(key).hexEncodedString()) ?? ""
      var grantor = Data(prefix)
      grantor.append(reqData[0..<64])
      let maskedGrantor = (try? sha512.hash(grantor).hexEncodedString()) ?? ""
      var value = Data(prefix)
      value.append(reqData[64..<128])
      let maskedValue = (try? sha512.hash(value).hexEncodedString()) ?? ""

      let observation = Observation(prefix: prefix.hexEncodedString(),
                                    timestamp: reqTime,
                                    grantor: maskedGrantor,
                                    key: maskedKey,
                                    value: maskedValue)
      guard let obsData = try? encoder.encode(observation),
            let obsJSON = String(data: obsData, encoding: .utf8) else {
        err("Problem encoding observation.")
        continue reqLoop
      }

      let msg = SQS.SendMessageRequest(delaySeconds: 0, messageAttributes: [:], messageBody: obsJSON, messageDeduplicationId: nil, messageGroupId: "test", queueUrl: queueUrl)

      do {
        _ = try sqs.sendMessage(msg).wait()
      } catch {
        err("\(error)")
        continue reqLoop
      }

      respond(body: #"{"status": 200, "msg": "OK"}"#, status: 200)
      continue reqLoop

    default:
      err("Input seems to be neither value or signature.)")
      continue reqLoop
  }

}
