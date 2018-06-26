import Foundation
import Vapor
import JavaScriptCore

public class Validator: NSObject {
    static let shared = Validator()
    private let vm = JSVirtualMachine()
    private let context: JSContext
    
    override init() {
        let fm = FileManager()
        let rootDirectory = DirectoryConfig.detect().workDir
        let jsDirectory = "\(rootDirectory)/Public"
        let files = try! fm.contentsOfDirectory(atPath: jsDirectory)
//        let jsCode = try! String.init(contentsOfFile: "\(jsDirectory)Zschema.bundle.js")
        let jsCode = String.init(data: fm.contents(atPath: "\(jsDirectory)/Zschema.bundle.js")!, encoding: .utf8) 
        self.context = JSContext(virtualMachine: self.vm)
        let nativeLog: @convention(block) (String) -> Void = { message in
            NSLog("JS Log: \(message)")
        }
        self.context.setObject(nativeLog, forKeyedSubscript: "nativeLog" as NSString)
        context.exceptionHandler = { context, exception in
            print("JS Error: \(exception?.description ?? "unknown error")")
        }
        self.context.evaluateScript(jsCode)
    }
    
    public func analyze(_ jsonUnderTest: String) -> Bool {
        var schema:String?
        guard let schemaUrl = URL.init(string: "https://raw.githubusercontent.com/alexa/alexa-smarthome/master/validation_schemas/alexa_smart_home_message_schema.json") else {fatalError()}
        let queue = DispatchQueue(label: "com.app.queue")
        queue.sync {
            schema = try? String.init(contentsOf: schemaUrl, encoding: .utf8)
        }
        let jsModule = self.context.objectForKeyedSubscript("Zschema")
        let jsAnalyzer = jsModule?.objectForKeyedSubscript("Analyzer")
        let result = jsAnalyzer?.invokeMethod("validate", withArguments: [jsonUnderTest, schema!]).toDictionary()
        guard
            let res = result,
            let p = res["valid"],
            let pass = p as? Bool
            else { fatalError() }
        //        let errors = rawErrors.toDictionary()
        if !pass {
            let errs = res["errors"] as! Array<[String:Any]>
            print("JSON validation error message is ", errs[0])
            print("JSON under test: \n\n\(jsonUnderTest)\n\n")
        }
        return pass
    }
}

