import Foundation
import Command
import Crypto

enum BlockMatchError: Error {
    case notSignature
    case notRecord
}

extension Data {
    init?(hex: String) {
        let str = hex.lowercased()
        guard str.count % 2 == 0 else {
            return nil
        }
        let hex: Set<Character> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
        guard Set(str).isSubset(of: hex) else {
            return nil
        }
        self.init(bytes: stride(from: 0, to: str.count, by: 2).map { i in
            return UInt8(str[str.index(str.startIndex, offsetBy: i)..<str.index(str.startIndex, offsetBy: i+2)].withCString { strtoul($0, nil, 16) }) 
        }) //nicely done Suguru
    }

}

struct Check {
    let block: String
    let keyset: Set<String>
}

struct Substitution: Codable {
    let hash: String
    let salt: String
    let value: String
}

struct Signature: Codable {
    let hash: String
    let pub: Data
    let signature: Data
}

struct KeyPair: Codable {
    let hash: String
    let priv: Data
    let pub: Data
    init() {
        var initial_priv: [UInt8] = []
        var initial_pub: [UInt8] = []
        for _ in 0...65 {
            var subkey: [UInt8] = []
            for _ in 0...63 {
                subkey.append(UInt8.random(in:0...255))
            }

            initial_priv.append(contentsOf: subkey)

            var hash = Data(bytes: subkey)
            for _ in 1...255 {
                hash = try! SHA512.hash(hash)
            }
            initial_pub.append(contentsOf: hash)
        }
        priv = Data(bytes: initial_priv)
        pub = Data(bytes: initial_pub)
        hash = (try! SHA512.hash(pub)).hexEncodedString()
    }

    init(hash: String, priv: Data, pub: Data) {
        self.hash = hash
        self.priv = priv
        self.pub = pub
    }
}

struct Record: Codable {
    let keys: [String]
    let hashes: [String]
    let timestamp: Int64
    let salt: String
}

struct OpenCPE {
    public static func generateKeyPair() -> KeyPair {
        return KeyPair()
    }

    public static func sign(_ hash: Data, withKeyPair keypair: KeyPair) -> Data {
        var signature: [UInt8] = []
        var distance = 255*64
        for i in 0...65 {
            let byte: UInt8
            switch i {
                case 64: 
                    byte = numericCast(distance/256)
                case 65:
                    byte = numericCast(distance-distance/256*256)
                default:
                    byte = hash[i]
            }
            let subkey = keypair.priv[(i*64)...(i*64+63)] 
            var subsig = subkey
            for _ in 0..<byte {
                subsig = try! SHA512.hash(subsig)
                if i < 64 {
                    distance -= 1
                }
            }
            signature.append(contentsOf: subsig)
        }
        return Data(bytes: signature)
    }

    public static func verify(_ sig: Signature, hash: Data, key keypair: KeyPair) -> Bool {
        var value: [UInt8] = []
        var distance: Int = 0
        for i in 0...65 {
            let subsig = sig.signature[(i*64)...(i*64+63)]
            let target = keypair.pub[(i*64)...(i*64+63)]
            var currentSig: Data = subsig
            for j in 0...255 {
                if currentSig == target {
                    value.append(numericCast(255 - j))
                    if (i < 64) {
                        distance += j
                    }
                    break;
                }
                do {
                    currentSig = try SHA512.hash(currentSig)
                } catch {
                    return false
                }
            }
            if i != value.count-1 {
                return false
            }
        }
        if distance != Int(value[64])*256+Int(value[65]) {
            return false
        }
        for i in 0...63 {
            if value[i] != hash[i] {
                return false
            }
        }
        return true
    }

}

struct OpenCPECommand: Command {
    var arguments: [CommandArgument] {
        return [
                .argument(name: "command", help: [
                                                    "keypair: generates a public and private keypair",
                                                    "sign: sign a file",
                                                    "verify: verify a file against a signature",
                                                    "mask: mask a value",
                                                    "sync: sync a blockchain",
                                                    "find: find a value in a blockchain",
                                                 ]),
               ]
    }

    var options: [CommandOption] {
        return [
                .value(name: "output", short: "o", help: ["output file"]),
                .value(name: "key", short: "k", help: ["key file"]),
                .value(name: "input", short: "i", help: ["input file"]),
                .value(name: "signature", short: "s", help: ["signature file"]),
                .value(name: "value", short: "v", help: ["value to mask or find"]),
                .value(name: "chain", short: "c", help: ["blockchain directory"]),
                .value(name: "top", short: "t", help: ["top block file"]),
                .value(name: "fundamental", short: "f", help: ["hash of fundamental key"]),
               ]
    }

    var help: [String] {
        return ["Generates and uses keys to sign and verify valid signatures of a file."]
    }

    func run(using ctx: CommandContext) throws -> Future<Void> {
        let console = ctx.console
        switch ctx.arguments["command"] {

            case "keypair":
                guard let output = ctx.options["output"] else {
                    console.print("need an output file")
                    exit(-1)
                }
                let keypair = OpenCPE.generateKeyPair()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [JSONEncoder.OutputFormatting.prettyPrinted]
                let data = try! encoder.encode(keypair)
                let hash = try! SHA512.hash(keypair.pub)
                console.print("outputting keypair: \(hash.hexEncodedString())")
                let outputFilePath = URL(fileURLWithPath: output)
                do {
                    try data.write(to:outputFilePath)
                } catch {
                    console.print("Error writing key: \(error)")
                    exit(-1)
                }

            case "sign":
                //import key
                guard let key = ctx.options["key"] else {
                    console.print("need a key file")
                    exit(-1)
                }
                let decoder = JSONDecoder()
                let keypair: KeyPair
                do {
                    keypair = try decoder.decode(KeyPair.self, from: try Data(contentsOf: URL(fileURLWithPath: key)))
                } catch {
                    console.print("Error importing key: \(error)")
                    exit(-1)
                }

                //read input
                guard let input = ctx.options["input"] else {
                    console.print("need an input file")
                    exit(-1)
                }
                let data: Data
                do {
                    data = try Data(contentsOf: URL(fileURLWithPath: input))
                } catch {
                    console.print("Error loading input file: \(error)")
                    exit(-1)
                }

                //hash input
                let hash: Data
                do {
                    hash = try SHA512.hash(data)
                } catch {
                    console.print("Error hashing input: \(error)")
                    exit(-1)
                }

                //calculate signature
                let sig = Signature(hash: hash.hexEncodedString(), pub: keypair.pub, signature: OpenCPE.sign(hash, withKeyPair: keypair))

                //output signature
                guard let output = ctx.options["output"] else {
                    console.print("need an output file")
                    exit(-1)
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [JSONEncoder.OutputFormatting.prettyPrinted]
                let json = try! encoder.encode(sig)
                let outputFilePath = URL(fileURLWithPath: output)
                do {
                    try json.write(to:outputFilePath)
                } catch {
                    console.print("Error writing key: \(error)")
                    exit(-1)
                }

            case "verify":
                //import key
                guard let key = ctx.options["key"] else {
                    console.print("need a key file")
                    exit(-1)
                }
                let decoder = JSONDecoder()
                let keypair: KeyPair
                do {
                    keypair = try decoder.decode(KeyPair.self, from: try Data(contentsOf: URL(fileURLWithPath: key)))
                } catch {
                    console.print("Error importing key: \(error)")
                    exit(-1)
                }

                //read input
                guard let input = ctx.options["input"] else {
                    console.print("need an input file")
                    exit(-1)
                }
                let data: Data
                do {
                    data = try Data(contentsOf: URL(fileURLWithPath: input))
                } catch {
                    console.print("Error loading input file: \(error)")
                    exit(-1)
                }

                //hash input
                let hash: Data
                do {
                    hash = try SHA512.hash(data)
                } catch {
                    console.print("Error hashing input: \(error)")
                    exit(-1)
                }

                //import signature
                guard let signature = ctx.options["signature"] else {
                    console.print("need a signature file")
                    exit(-1)
                }
                let sig: Signature
                do {
                    sig = try decoder.decode(Signature.self, from: try Data(contentsOf: URL(fileURLWithPath: signature)))
                } catch {
                    console.print("Error importing signature: \(error)")
                    exit(-1)
                }

                if OpenCPE.verify(sig, hash: hash, key: keypair) {
                    console.print("verified")
                } else {
                    console.print("verification failed")
                    exit(-1)
                }

            case "mask":
                guard let value = ctx.options["value"] else {
                    console.print("need a value")
                    exit(-1)
                }
                var bytes: [UInt8] = []
                for _ in 0...63 {
                    bytes.append(UInt8.random(in:0...255))
                }
                let salt = Data(bytes: bytes)
                bytes.append(contentsOf:[UInt8](value.data(using: .utf8)!))
                let hash:Data 
                do {
                    hash = try SHA512.hash(Data(bytes: bytes))
                } catch {
                    console.print("Problem processing value: \(error).")
                    exit(-1)
                }

                guard let output = ctx.options["output"] else {
                    console.print("need an output file")
                    exit(-1)
                }
                let sub = Substitution(hash: hash.hexEncodedString(), salt: salt.hexEncodedString(), value: value)

                let encoder = JSONEncoder()
                encoder.outputFormatting = [JSONEncoder.OutputFormatting.prettyPrinted]
                let data = try! encoder.encode(sub)
                let outputFilePath = URL(fileURLWithPath: output)
                do {
                    try data.write(to:outputFilePath)
                } catch {
                    console.print("Error writing substitution: \(error)")
                    exit(-1)
                }

            case "sync":
                console.print("This feature will sync this utility with the master blockchain.")
                exit(-1)

            case "find":
                guard let value = ctx.options["value"], let dataValue = value.data(using: .utf8) else {
                    console.print("need a value")
                    exit(-1)
                }

                guard let fundamental = ctx.options["fundamental"] else {
                    console.print("need hash of fundamental key")
                    exit(-1)
                }

                guard let top = ctx.options["top"] else {
                    console.print("need the top block")
                    exit(-1)
                }

                let topFilePath = URL(fileURLWithPath: top)
                let path = topFilePath.deletingLastPathComponent()

                var checks = [Check(block: topFilePath.lastPathComponent, keyset: Set<String>())]

                let decoder = JSONDecoder()

                var grace = true

                while !checks.isEmpty {
                    checks.shuffle()
                    let check = checks.popLast()!
                    guard let block = try? Data(contentsOf: path.appendingPathComponent(check.block, isDirectory: false)) else {
                        console.print("couldn't read \(check.block)")
                        continue;
                    }

                    console.print("processing \(check.block)")

                    if try check.block != SHA512.hash(block).hexEncodedString() {
                        console.print("\tblock has inconsistent hash")
                        continue
                    }

                    do {
                        let sig = try decoder.decode(Signature.self, from: block)
                        console.print("\tidentified signature block")
                        let keypair = KeyPair(hash: sig.hash, priv: Data(), pub: sig.pub)
                        guard let hash = Data(hex: sig.hash) else {
                            console.print("\tinvalid hash")
                            throw BlockMatchError.notSignature
                        }
                        if OpenCPE.verify(sig, hash: hash, key: keypair) {
                            console.print("\tverified signature!")
                        } else {
                            console.print("\tcouldn't verify signature")
                            throw BlockMatchError.notSignature
                        }
                        let keysetp = check.keyset.union([try SHA512.hash(sig.pub).hexEncodedString()])
                        checks.append(Check(block: hash.hexEncodedString(), keyset: keysetp))
                        continue
                    } catch {}

                    do {
                        let rec = try decoder.decode(Record.self, from: block)
                        if grace {
                            grace = false
                            rec.hashes.forEach { hash in
                                checks.append(Check(block: hash, keyset: check.keyset))
                            }
                            throw BlockMatchError.notRecord
                        }
                        console.print("\tidentified record block")
                        guard check.keyset.intersection(Set(rec.keys)).count > 0 else {
                            console.print("\tmismatched key series")
                            exit(-1)
                        }
                        if check.keyset.contains(fundamental) && check.keyset.contains(value) {
                            console.print("\nvalue found in chain!")
                            exit(0)
                        }
                        var localKeyset = check.keyset
                        if !check.keyset.contains(value), let salt = Data(hex: rec.salt) {
                            console.print("\tsearching record")
                            var data = salt
                            data.append(dataValue)
                            if let target = try? SHA512.hash(data).hexEncodedString() {
                                rec.hashes.forEach { hash in 
                                    if target == hash {
                                        console.print("\ttarget found with timestamp: \(rec.timestamp)!")
                                        localKeyset = localKeyset.union([value])
                                    }
                                }
                            }
                        } 
                        rec.hashes.forEach { hash in
                            checks.append(Check(block: hash, keyset: localKeyset))
                        }
                        continue
                    } catch {}

                    console.print("\tcould not find block type")
                }

                console.print("\nvalue not found in chain")
                exit(-1)

            default:
                console.print("Command is unrecognized.")
                exit(-1)
        }
        return .done(on: ctx.container)
    }
}

let console = Terminal()
let thread = MultiThreadedEventLoopGroup(numberOfThreads: 1)
var env = Environment(name: "Initial", isRelease: true, arguments: CommandLine.arguments)
var container = BasicContainer(config: Config(), environment: env, services: Services(), on: thread)
do {
    try console.run(OpenCPECommand(), input: &env.commandInput, on: container).wait()
} catch {
    exit(-1)
}
exit(0)
