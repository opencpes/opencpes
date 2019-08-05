import Foundation
import Glibc
import Crypto
import BChain
import SQS
import S3

typealias SubBlock = (observation: Observation,receipt: String)

fputs("Retrieving configuration.\n",stderr)

guard let queueUrl = ProcessInfo.processInfo.environment["QUEUEURL"],
      let accessKeyId = ProcessInfo.processInfo.environment["ACCESSKEYID"],
      let secretAccessKey = ProcessInfo.processInfo.environment["SECRETACCESSKEY"] else {
  fputs("Can't get queueUrl\n", stderr)
  exit(-1)
}

let sha512 = Digest(algorithm: .sha512)
let encoder = JSONEncoder()
encoder.outputFormatting = [JSONEncoder.OutputFormatting.prettyPrinted,JSONEncoder.OutputFormatting.sortedKeys]
let decoder = JSONDecoder()
let sqs = SQS(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, region: .useast2)
let sqsReq = SQS.ReceiveMessageRequest(maxNumberOfMessages: 10, queueUrl: queueUrl, waitTimeSeconds: 10)
let s3 = S3(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, region: .useast2)
let s3TopReq = S3.GetObjectRequest(bucket: "blocks-blockchain-demo-opencpes-com", key: "top")

fputs("Entering main loop.\n",stderr)
mainLoop: while true {

  fputs("Getting messages.\n",stderr)
  var rawMsgs = [SQS.Message](), gotSome = false
  repeat {
    guard let result = try? sqs.receiveMessage(sqsReq).wait(),
          let messages = result.messages else {
      gotSome = false
      continue
    }
    gotSome = true
    rawMsgs += messages
  } while gotSome

  var subBlocks = [SubBlock]()
  for rawMsg in rawMsgs {
    guard let body = rawMsg.body,
          let receipt = rawMsg.receiptHandle,
          let observation = try? decoder.decode(Observation.self, from: body) else {
      continue
    }
    subBlocks.append((observation: observation, receipt: receipt))
  }

  if (subBlocks.count < 1) {
    fputs("No incoming message.\n",stderr)
    continue mainLoop
  }

  var sec:Data
  var secp:String
  var top = (try? s3.getObject(s3TopReq).wait())?.body ?? Data()
  var topp:String
  if (top.count == 4352) {
    fputs("Top block is a signature.\n",stderr)
    do {
      topp = try sha512.hash(top).hexEncodedString()
    } catch {
      fputs("Couldn't hash top: \(error).\n",stderr)
      continue mainLoop
    }
    fputs("Writing top to the blockchain.\n",stderr)
    let s3PutTop = S3.PutObjectRequest(acl: .publicRead, body: top, bucket: "blocks-blockchain-demo-opencpes-com", contentType: "application/octet-stream", key: topp)
    do {
      _ = try s3.putObject(s3PutTop).wait()
    } catch {
      fputs("Couldn't write top: \(error)\n",stderr)
      continue mainLoop
    }
    fputs("Creating new secret.\n",stderr)
    sec = BChain.createSecretKey()
    do {
      let pub = try BChain.createPublicKey(fromSecretKey: sec)
      secp = try sha512.hash(pub).hexEncodedString()
    } catch {
      fputs("Couldn't hash k': \(error).\n", stderr)
      continue mainLoop
    }
    fputs("Putting new secret in keychain.\n",stderr)
    let s3PutKey = S3.PutObjectRequest(body: sec, bucket: "keys-blockchain-demo-opencpes-com", contentType: "application/octet-stream", key: secp) 
    do {
      _ = try s3.putObject(s3PutKey).wait()
    } catch {
      fputs("Couldn't publish k': \(error).\n", stderr)
      continue mainLoop
    }
    fputs("Generating new block.\n",stderr)
    let newBlock = Block(timestamp: Int(Date().timeIntervalSince1970), 
                      observations: subBlocks.map {$0.observation},
                      beneficiary: secp,
                      extends: topp)
    guard let blockData = try? encoder.encode(newBlock),
          let blockHash = try? sha512.hash(blockData).hexEncodedString() else {
      fputs("Couldn't encode and hash new block.\n",stderr)
      continue mainLoop
    }
    fputs("Adding new block to the chain.\n",stderr)
    let s3PutBlock = S3.PutObjectRequest(acl: .publicRead, body: blockData, bucket: "blocks-blockchain-demo-opencpes-com", contentType: "application/json", key: blockHash) 
    do {
      _ = try s3.putObject(s3PutBlock).wait()
    } catch {
      fputs("Couldn't publish block: \(error).\n",stderr)
      continue mainLoop
    }
    fputs("Setting top to new block.\n",stderr)
    let s3PutBlockHead = S3.PutObjectRequest(acl: .publicRead, body: blockData, bucket: "blocks-blockchain-demo-opencpes-com", contentType: "application/json", key: "top") 
    do {
      _ = try s3.putObject(s3PutBlockHead).wait()
    } catch {
      fputs("Couldn't publish block to top: \(error).\n",stderr)
      continue mainLoop
    }
  }

  fputs("Getting top.\n",stderr)
  top = (try? s3.getObject(s3TopReq).wait())?.body ?? Data()
  if (top.count == 0) {
    fputs("Problem getting top.\n",stderr)
    continue mainLoop
  }

  guard let block = try? decoder.decode(Block.self, from: top) else {
    fputs("Problem decoding top block.\n",stderr)
    continue mainLoop
  }

  fputs("Generating message dictionary.\n",stderr)
  var receipts = [Observation:String]()
  _ = subBlocks.map {receipts[$0.observation] = $0.receipt}

  fputs("Deleting messages in block.\n",stderr)
  for observation in block.observations {
    if (receipts[observation] != nil) {
      let sqsDel = SQS.DeleteMessageRequest(queueUrl: queueUrl, receiptHandle: receipts[observation]!)
      do {
        _ = try sqs.deleteMessage(sqsDel).wait()
      } catch {
        fputs("Couldn't delete message: \(error).\n",stderr)
      }
    }
  }

  fputs("Getting block before this one.\n",stderr)
  let s3LastSigReq = S3.GetObjectRequest(bucket: "blocks-blockchain-demo-opencpes-com", key: block.extends)
  guard let lastBlockBody = (try? s3.getObject(s3LastSigReq).wait())?.body else {
    fputs("Problem getting last block info.\n",stderr)
    continue mainLoop
  }
  let lastBlockHash = lastBlockBody[64..<128].hexEncodedString()
  fputs("Getting the block before that.\n",stderr)
  let s3LastBlockReq = S3.GetObjectRequest(bucket: "blocks-blockchain-demo-opencpes-com", key: lastBlockHash)
  guard let lastBlockData = (try? s3.getObject(s3LastBlockReq).wait())?.body,
        let lastBlock = try? decoder.decode(Block.self, from: lastBlockData) else {
    fputs("Problem getting the block before last.\n",stderr)
    continue mainLoop
  }

  fputs("Getting the block before last's recommend key.\n",stderr)
  let s3LastKeyReq = S3.GetObjectRequest(bucket: "keys-blockchain-demo-opencpes-com", key: lastBlock.beneficiary)
  guard let lastKey = (try? s3.getObject(s3LastKeyReq).wait())?.body else {
    fputs("Problem getting the last key.\n",stderr)
    continue mainLoop
  }

  fputs("Hashing current block.\n",stderr)
  guard let blockHash = try? sha512.hash(top) else {
    fputs("Problem hashing block.\n",stderr)
    continue mainLoop
  }

  fputs("Getting grantor.\n",stderr)
  guard let oldHash = try? sha512.hash(lastBlockBody[0..<128]),
        let grantor = try? BChain.createPublicKey(fromSignature: lastBlockBody[128..<4352], value: oldHash),
        let grantorHash = try? sha512.hash(grantor) else {
    fputs("Problem getting grantor.\n",stderr)
    continue mainLoop
  }

  var value = Data(capacity: 128)
  value.append(grantorHash)
  value.append(blockHash)

  fputs("Hashing value.\n",stderr)
  guard let valueHash = try? sha512.hash(value) else {
    fputs("Problem hashing value.\n",stderr)
    continue mainLoop
  }

  fputs("Signing value.\n",stderr)
  guard let sigMini = try? BChain.sign(valueHash, secretKey: lastKey) else {
    fputs("Problem signing value.\n",stderr)
    continue mainLoop
  }

  fputs("Creating signature.\n",stderr)
  var sig = Data(capacity: 4352)
  sig.append(grantorHash)
  sig.append(blockHash)
  sig.append(sigMini)

  fputs("Setting top to signature.\n",stderr)
  let s3PutSigHead = S3.PutObjectRequest(acl: .publicRead, body: sig, bucket: "blocks-blockchain-demo-opencpes-com", contentType: "application/octet-stream", key: "top") 
  do {
    _ = try s3.putObject(s3PutSigHead).wait()
  } catch {
    fputs("Couldn't publish sig to top: \(error).\n",stderr)
    continue mainLoop
  }

  guard let sigHash = try? sha512.hash(sig).hexEncodedString() else {
    fputs("Problem hashing signature.\n",stderr)
    continue mainLoop
  }

  fputs("Adding signature to the chain.\n",stderr)
  let s3PutSig = S3.PutObjectRequest(acl: .publicRead, body: sig, bucket: "blocks-blockchain-demo-opencpes-com", contentType: "application/octet-stream", key: sigHash) 
  do {
    _ = try s3.putObject(s3PutSig).wait()
  } catch {
    fputs("Couldn't publish sig: \(error).\n",stderr)
    continue mainLoop
  }

}
