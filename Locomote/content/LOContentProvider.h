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
#import "LOLocalCachePaths.h"
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
@property (nonatomic, strong) NSDictionary<NSString *, id<LOContentAuthority>> *authorities;
/// Path settings for locally cached content.
@property (nonatomic, strong) LOLocalCachePaths *localCachePaths;

/// Add a content authority.
- (void)setContentAuthority:(id<LOContentAuthority>)authority withName:(NSString *)name;
/// Find a content authority by name, or return nil if no match found.
- (id<LOContentAuthority>)contentAuthorityForName:(NSString *)name;
/**
 * Synchronize all content authorities with their remote sources.
 * @return A promise which resolves once all authorities have synchronized.
 */
- (QPromise *)syncAuthorities;
/**
 * Test whether the provider has content for the file with the specified path.
 * The file path must have a content authority name prefix (e.g. account.repo/).
 * Returns true if the relevant content authority has content for the file with
 * the specified path.
 */
- (BOOL)hasContentForPath:(NSString *)path;
/**
 * Get the path of the local cache location of the file with the specified path.
 * The file path must have a content authority name prefix (e.g. account.repo/).
 * Returns the path to the location where the local copy of the file is cached.
 * This may be (i) a path to the app bundle, if the file is packaged with the app;
 * (ii) a path to one of the app's cache locations; or (iii) _nil_ if the file
 * isn't cached locally.
 */
- (NSString *)localCacheLocationOfPath:(NSString *)path;
/// Return the singleton instance of this class.
+ (LOContentProvider *)getInstance;

@end
