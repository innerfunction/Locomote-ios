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
//  Created by Julian Goacher on 28/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOContentAuthority.h"
#import "LOCommandQueue.h"
#import "SCIOCTypeInspectable.h"
#import "SCIOCSingleton.h"
#import "SCService.h"
#import "SCMessageRouter.h"
#import "SCMessageReceiver.h"
#import "Q.h"

/**
 * A provider of content to the content: URL protocol.
 * A content provider is a collection of content authorities, each encapsulating different
 * content sources (e.g. different content repos).
 */
@interface LOContentProvider : NSObject <SCIOCSingleton, SCIOCTypeInspectable, SCService, SCMessageRouter, SCMessageReceiver>

/// A map of content authority instances keyed by authority name.
@property (nonatomic, strong) NSDictionary *authorities;
/// A command queue for executing commands for the different content authorities.
@property (nonatomic, strong) LOCommandQueue *commandQueue;
/// A path for temporarily staging downloaded content.
@property (nonatomic, strong) NSString *stagingPath;
/// A path for caching app content.
@property (nonatomic, strong) NSString *appCachePath;
/// A path for caching downloaded content.
@property (nonatomic, strong) NSString *contentCachePath;
/// A path for app packaged content.
@property (nonatomic, strong) NSString *packagedContentPath;

/// Add a content authority.
- (void)setContentAuthority:(id<LOContentAuthority>)authority withName:(NSString *)name;
/// Find a content authority by name, or return nil if no match found.
- (id<LOContentAuthority>)contentAuthorityForName:(NSString *)name;
/**
 * Synchronize all content authorities with their remote sources.
 * @return A promise which resolves once all authorities have synchronized.
 */
- (QPromise *)syncAuthorities;
/// Return the singleton instance of this class.
+ (LOContentProvider *)getInstance;

@end
