import Foundation 
import CommonCrypto

public enum Algorithm {
  case sha512
}

public class Digest {
  public init(algorithm: Algorithm) {} 

  public func hash(_ data: Data) throws -> Data {
    let nsdata = data as NSData
    var sum = [UInt8](repeating: 0, count: 64)
    CC_SHA512(nsdata.bytes, CC_LONG(data.count), &sum)
    return Data(sum)
  }

}

public class BChain {
  public static func createSecretKey() -> Data {
    var key = Data(capacity: 4224)
    for _ in 0..<4224 {
      key.append(UInt8.random(in: 0...255))
    }
    return key
  }

  public static func createPublicKey(fromSecretKey k: Data) throws -> Data {
    var key = Data(capacity: 4224)
    key.append(k)
    let sha512 = Digest(algorithm: .sha512)
    for i in stride(from: 0, to: 4224, by: 64) {
      for _ in 1...255 {
        key.replaceSubrange(i..<i+64, with: try sha512.hash(key[i..<i+64]))
      }
    }
    return key
  }

  public static func createPublicKey(fromSignature sig: Data, value: Data) throws -> Data {
    var key = Data(capacity: 4224)
    key.append(sig)
    let sha512 = Digest(algorithm: .sha512)
    var rolls = 0
    for i in 0..<64 {
      for _ in 0..<255-value[i] {
        key.replaceSubrange(i*64..<i*64+64, with: try sha512.hash(key[i*64..<i*64+64]))
      }
      rolls += Int(255-value[i])
    }
    for _ in 0..<255-rolls/256 {
        key.replaceSubrange(64*64..<64*64+64, with: try sha512.hash(key[64*64..<64*64+64]))
    }
    for _ in 0..<255-(rolls-rolls/256*256) {
        key.replaceSubrange(65*64..<65*64+64, with: try sha512.hash(key[65*64..<65*64+64]))
    }
    return key
  }

  public static func sign(_ value: Data, secretKey key: Data) throws -> Data {
    var sig = Data(capacity: 4224)
    sig.append(key)
    let sha512 = Digest(algorithm: .sha512)
    var rolls = 0
    for i in 0..<64 {
      for _ in 0..<value[i] {
        sig.replaceSubrange(i*64..<i*64+64, with: try sha512.hash(sig[i*64..<i*64+64]))
      }
      rolls += Int(255-value[i])
    }
    for _ in 0..<rolls/256 {
        sig.replaceSubrange(64*64..<64*64+64, with: try sha512.hash(sig[64*64..<64*64+64]))
    }
    for _ in 0..<rolls-rolls/256*256 {
        sig.replaceSubrange(65*64..<65*64+64, with: try sha512.hash(sig[65*64..<65*64+64]))
    }
    return sig
  }
}

extension Data {
  public func hexEncodedString() -> String {
    return ((self.map {String($0, radix: 16)}).map {
      if $0.count < 2 {
        return "0" + $0
      } else {
        return $0
      }
    }).joined(separator: "")
  }
}

public struct Block: Codable {
  public let timestamp: Int
  public let observations: [Observation]
  public let beneficiary: String
  public let extends: String

  public init(timestamp: Int, observations: [Observation], beneficiary: String, extends: String) {
    self.timestamp = timestamp
    self.observations = observations
    self.beneficiary = beneficiary
    self.extends = extends
  }
}

public struct Observation: Codable, Hashable {
  public let prefix: String
  public let timestamp: Int
  public let grantor: String
  public let key: String
  public let value: String

  public init(prefix: String, timestamp: Int, grantor: String, key: String, value: String) {
    self.prefix = prefix
    self.timestamp = timestamp
    self.grantor = grantor
    self.key = key
    self.value = value
  }

  public static func == (lhs: Observation, rhs: Observation) -> Bool {
    return lhs.prefix == rhs.prefix &&
           lhs.timestamp == rhs.timestamp &&
           lhs.grantor == rhs.grantor &&
           lhs.key == rhs.key &&
           lhs.value == rhs.value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(prefix)
    hasher.combine(timestamp)
    hasher.combine(grantor)
    hasher.combine(key)
    hasher.combine(value)
  }

}
