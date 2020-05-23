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

internal class Shell {
    internal static let shared = Shell(command: "")
    
    private(set) public lazy var curl = Shell(command: "curl").resolve()
    private(set) public lazy var openssl = Shell(command: "openssl").resolve()
    
    private let command: String
    private var fullPath: String?
    
    private init(command: String) {
        self.command = command
    }
    
    private func resolve() -> Shell {
        let result = launch(path: "/usr/bin/which", arguments: [command])
        guard result.status == 0, let path = result.values.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
            fatalError()
        }
        
        fullPath = path
        return self
    }
    
    internal func launch(_ arguments: [String]) -> Result {
        launch(path: fullPath!, arguments: arguments)
    }
    
    public typealias Result = (values: [String], status: Int32)
    fileprivate func launch(path launchPath: String, arguments: [String] = [], grep: String? = nil) -> Result {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        task.waitUntilExit()
        
        guard let string = output else {
            return ([], task.terminationStatus)
        }
        
        guard let grep = grep else {
            return ([string], task.terminationStatus)
        }
        
        let lines = string.components(separatedBy: CharacterSet.newlines)
        var result = [String]()
        for line in lines {
            if let _ = line.range(of: grep) {
                result.append(line)
            }
        }
        
        return (result, task.terminationStatus)
    }
}
