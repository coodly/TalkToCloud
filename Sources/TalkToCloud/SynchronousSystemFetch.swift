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

extension URLSession {
    public func synchronousDataWithRequest(request: URLRequest, completionHandler: (Data?, URLResponse?, Error?) -> Void) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let sem = DispatchSemaphore(value: 0)
        
        let task = dataTask(with: request) {
            data = $0
            response = $1
            error = $2
            sem.signal()
        }
        
        task.resume()
        
        sem.wait()
        completionHandler(data, response, error)
    }
}

extension NetworkFetch {
    public static let synchronousSystemFetch = NetworkFetch(
        onFetch: URLSession.shared.synchronousDataWithRequest(request:completionHandler:)
    )
}
