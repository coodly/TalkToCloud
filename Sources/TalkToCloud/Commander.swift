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

public class Commander<C: Command> {
    private let arguments: [String]
    private let containerId: String
    public init(containerId: String, arguments: [String]) {
        self.arguments = arguments
        self.containerId = containerId
    }
    
    public func run() {
        Logging.log("Run \(String(describing: C.self))")
        Logging.log("Arguments: \(arguments)")
        let command = C()
        
        #if os(Linux)
        let fetch = CommandLineFetch()
        #else
        let fetch = SynchronousSystemFetch()
        #endif
        
        let config = Configuration(containerId: containerId)
        if var consumer = command as? ContainerConsumer {
            consumer.container = containerFromArguments(config: config, fetch: fetch)!
        }
        
        if var consumer = command as? DevelopmentConsumer {
            consumer.developmentContainer = config.developmentContainer(with: fetch)
        }
        
        if var consumer = command as? ProductionConsumer {
            consumer.productionContainer = config.productionContainer(with: fetch)
        }
        
        var remaining = arguments
        remaining.removeFirst()
        let toRemove = ["--production", "--development"]
        for remove in toRemove {
            if let index = remaining.firstIndex(of: remove) {
                remaining.remove(at: index)
            }
        }
        
        Logging.log("Command arguments: \(remaining)")
        command.execute(with: remaining)
    }
    
    private func containerFromArguments(config: Configuration, fetch: NetworkFetch) -> CloudContainer? {
        if arguments.contains("--production") {
            return config.productionContainer(with: fetch)
        } else if arguments.contains("--development") {
            return config.developmentContainer(with: fetch)
        } else {
            Logging.log("No environment defined. We will crash now 8-|")
            return nil
        }
    }
}
