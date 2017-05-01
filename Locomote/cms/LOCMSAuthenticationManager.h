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
//  Created by Julian Goacher on 30/11/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOCMSSettings.h"
#import "SCHTTPClient.h"

/// A class for managing HTTP authentication on CMS server requests.
@interface LOCMSAuthenticationManager : NSObject <NSURLSessionTaskDelegate> {
    NSURLProtectionSpace *_protectionSpace;
}

/// Initialize an authentication manager for the named authentication realm.
- (id)initWithCMSSettings:(LOCMSSettings *)cms;

/**
 * Register basic auth credentials to be used with subsequent requests.
 * The _credentials_ dictionary should have _username_ and _password_ values.
 */
- (void)registerCredentials:(NSDictionary *)credentials;
/// Register basic auth credentials to be used with subsequent requests.
- (void)registerUsername:(NSString *)username password:(NSString *)password;
/// Test if the manager has registered credentials.
- (BOOL)hasCredentials;
/// Remove any registered credentials.
- (void)removeCredentials;

@end