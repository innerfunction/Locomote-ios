// Copyright 2018 InnerFunction Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  Created by Julian Goacher on 01/06/2018.
//

#import <Foundation/Foundation.h>
#import "LOOperationQueue.h"
#import "LOHTTPAuthenticationManager.h"
#import "LOCMSFileDB.h"
#import "LOCMSSettings.h"
#import "SCHTTPClient.h"
#import "Q.h"

/**
 * An operation protocol for interacting with the Locomote CMS API.
 * The protocol is composed of a number of different asynchronous operations for downloading
 * updates from the Locomote server and managing the DB and local cache state.
 * All operations are executed sequentially on a background queue.
 */
@interface LOCMSOperationProtocol : NSObject {
    LOOperationQueue *_opQueue;
    __weak LOCMSFileDB *_fileDB;
    __weak LOCMSSettings *_settings;
    __weak SCHTTPClient *_httpClient;
    __weak LOHTTPAuthenticationManager *_authManager;
    QPromise *_promise;
}

- (id)initWithFileDB:(LOCMSFileDB *)fileDB
            settings:(LOCMSSettings *)settings
          httpClient:(SCHTTPClient *)httpClient
authenticationManager:(LOHTTPAuthenticationManager *)authManager;

- (QPromise *)refresh:(NSString *)updatesURL;

@end
