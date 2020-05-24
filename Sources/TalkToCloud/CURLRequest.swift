/*
* Copyright 2020 Coodly LLC
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

internal class CURLRequest {
    private lazy var identifier = UUID().uuidString
    private lazy var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    private lazy var sent = self.directory.appendingPathComponent("\(self.identifier)-sent")
    private lazy var received = self.directory.appendingPathComponent("\(self.identifier)-received")
    private lazy var headers = self.directory.appendingPathComponent("\(self.identifier)-headers")
    private let request: URLRequest
    private let autoClean: Bool
    public init(request: URLRequest, autoClean: Bool = true) {
        self.request = request
        self.autoClean = autoClean
    }
    
    deinit {
        guard autoClean else {
            return
        }
        
        FileManager.default.remove([sent, received, headers])
    }
    
    internal func execute(completion: (Data?, URLResponse?, Error?) -> ()) {
        var arguments = [String]()
        arguments.append("--location")
        arguments.append("--dump-header")
        arguments.append(headers.path)
        request.allHTTPHeaderFields?.forEach() {
            key, value in
            
            if key.lowercased() == "user-agent" {
                arguments.append("-A")
                arguments.append("\"\(value)\"")
            } else {
                arguments.append("-H")
                arguments.append("\(key): \(value)")
            }
        }
        if let body = request.httpBody {
            try! body.write(to: sent)
            arguments.append("--data-binary")
            arguments.append("@\(sent.path)")
        }
        arguments.append("--output")
        arguments.append(received.path)
        arguments.append(request.url!.absoluteString)
        
        Logging.verbose("curl \(arguments.joined(separator: " "))")
        
        let result = Shell.shared.curl.launch(arguments)
        assert(result.status == 0)
        
        result.values.forEach() {
            value in
            
            value.components(separatedBy: "\n").forEach({ Logging.verbose("\t\($0)") })
        }
        
        let data = try? Data(contentsOf: received)
        completion(data, nil, nil)
    }
}
