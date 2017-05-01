// Copyright 2017 InnerFunction Ltd.
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
//  Created by Julian Goacher on 08/12/2015.
//  Copyright © 2015 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOCommand.h"
#import "SCHTTPClient.h"

/**
 * A command to get the contents of a URL and write it to a file.
 * Arguments: <url> <filename> <retries>
 * - url:       The URL to fetch.
 * - filename:  The name of the file to write the result to.
 * - attempt:   The number of attempts made to fetch the URL. Defaults to 0 and is incremented after
 *              each failed attempt. The command fails once maxRetries number of attempts has been made.
 */
@interface LOGetURLCommand : NSObject <LOCommand> {
    SCHTTPClient *_httpClient;
    QPromise *_promise;
    NSString *_commandName;
    NSString *_url;
    NSString *_filename;
    NSMutableArray *_requestWindow;
}

- (id)initWithHTTPClient:(SCHTTPClient *)httpClient;

@property (nonatomic, assign) NSInteger maxRetries;
@property (nonatomic, assign) float maxRequestsPerMinute;

@end
