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

internal struct Variables {
    let container: String
    let env: Environment
    let auth: Authenticator
    let fetch: NetworkFetch
}

internal class Request<T: Decodable> {
    private enum Method: String {
        case post = "POST"
        case get = "GET"
    }
    
    private lazy var decoder = JSONDecoder()
    
    private let baseURL = URL(string: "https://api.apple-cloudkit.com/database/1/")!
    private let variables: Variables
    private var handler: ((Result<T, Error>) -> Void)?
    private var result: Result<T, Error>? {
        didSet {
            handler?(result!)
        }
    }
    
    internal init(variables: Variables) {
        self.variables = variables
    }
    
    internal func performRequest() {
        fatalError()
    }
    
    internal func perform(completion: @escaping ((Result<T, Error>) -> Void)) {
        handler = completion
        performRequest()
    }
    
    internal func get(from path: String, database: CloudDatabase = .private) {
        execute(.get, to: path, in: database)
    }
    
    internal func post(to path: String) {
        execute(.post, to: path)
    }
    
    private func execute(_ method: Method, to path: String, in database: CloudDatabase = .public) {
        let fullQueryPath = "\(variables.container)/\(variables.env.rawValue)/\(database.rawValue)\(path)"
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        components.path = components.path.appending(fullQueryPath)
        
        var url = components.url!
        
        for (name, value) in variables.auth.params {
            url = url.appending(param: name, value: value)
        }
        
        Logging.log("\(method.rawValue) to \(url.absoluteString)")
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = method.rawValue
        
        variables.fetch.fetch(request as URLRequest, completion: handle(_:response:error:))
    }
    
    private func handle(_ data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            Logging.log(error)
            result = .failure(CloudError.network(error))
            return
        }
        
        guard let data = data else {
            Logging.log("No response data")
            result = .failure(CloudError.noData)
            return
        }
        
        if let string = String(data: data, encoding: .utf8) {
            Logging.verbose(string)
        }
        
        result = decodeValue(from: data)
    }
    
    private func decodeValue<T: Decodable>(from data: Data) -> Result<T, Error> {
        do {
            let value = try decoder.decode(T.self, from: data)
            return .success(value)
        } catch {
            Logging.error("Decode error: \(error)")
            return .failure(decodeError(from: data, fallback: error))
        }
    }
    
    private func decodeError(from data: Data, fallback: Error) -> Error {
        if let error = try? decoder.decode(Raw.Error.self, from: data) {
            return error.presented
        } else {
            return fallback
        }
    }
}
