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
//  Created by Julian Goacher on 26/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOCMSFileset.h"

#define CacheDirName ([@"~" stringByAppendingString:_category])

@implementation LOCMSFileset

- (void)setCache:(NSString *)cache {
    _cache = cache;
    _cachable = ([@"content" isEqualToString:cache] || [@"app" isEqualToString:cache]);
}

- (NSString *)cachePath:(LOCMSRepository *)repository {
    NSString *path = nil;
    if ([@"content" isEqualToString:_cache]) {
        path = [repository.contentCachePath stringByAppendingString:CacheDirName];
    }
    else if ([@"app" isEqualToString:_cache]) {
        path = [repository.appCachePath stringByAppendingString:CacheDirName];
    }
    return path;
}

#pragma mark - SCIOCObjectAware

- (void)notifyIOCObject:(id)object propertyName:(NSString *)propertyName {
    // Record the fileset's category name as the name this object is bound to in its parent object.
    _category = propertyName;
}

#pragma mark - Class methods

+ (LOCMSFileset *)filesetWithCache:(NSString *)cache mappings:(NSArray *)mappings {
    LOCMSFileset *fileset = [LOCMSFileset new];
    fileset.cache = cache;
    fileset.mappings = mappings;
    return fileset;
}

@end