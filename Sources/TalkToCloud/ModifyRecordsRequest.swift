/*
 * Copyright 2021 Coodly LLC
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

internal class ModifyRecordsRequest: Request<Raw.Response> {
    private let body: Raw.Request
    private let database: CloudDatabase
    internal init(body: Raw.Request, database: CloudDatabase, variables: Variables) {
        self.body = body
        
        self.database = database
        
        super.init(variables: variables)
    }
    
    override func performRequest() {
        post(to: "/records/modify", body: body, in: database)
    }
}