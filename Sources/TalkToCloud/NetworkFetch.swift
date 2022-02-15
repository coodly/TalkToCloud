/*
 * Copyright 2016 Coodly LLC
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

public typealias NetworkFetchClosure = (Data?, URLResponse?, Error?) -> ()

public struct NetworkFetch {
    private let onFetch: ((URLRequest, NetworkFetchClosure) -> Void)
    
    public init(onFetch: @escaping ((URLRequest, NetworkFetchClosure) -> Void)) {
        self.onFetch = onFetch
    }
    
    public func fetch(_ request: URLRequest, completion: NetworkFetchClosure) {
        onFetch(request, completion)
    }
}
