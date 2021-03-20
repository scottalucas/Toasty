import JWT
import Crypto

struct TokenManager {
	struct Payload: JWTPayload {
		func verify(using signer: JWTSigner) throws {}
		init(timeout to: TimeInterval = 10, tokenType type: String = "Basic") {
			exp = Date(timeIntervalSinceNow: to)
			sub = type
		}
		let iss: String = "ToastyFireplace"
		let sub: String
		var exp: Date
	}
	
	static private var privateKey: RSAKey? {
		guard
			let privateKeyData = ENV.privateKey.data(using: .utf8)
			else {
				print("Couldn't load key.")
				return nil
		}
		return try? RSAKey.private(pem: privateKeyData)
	}

	static var basicToken: String? {
		var token = JWT<Payload>(payload: Payload())
		token.header.kid = ENV.keyVersion
		guard
			let privateKeyData = privateKey,
            let d = try? token.sign(using: .rs256(key: privateKeyData))
		else { print ("Couldn't sign token."); return nil }
		return String(data: d, encoding: .utf8)
	}

}
