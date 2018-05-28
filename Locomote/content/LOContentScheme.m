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
//  Created by Julian Goacher on 26/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import "LOContentScheme.h"
#import "LOContentProvider.h"
#import "LOContentAuthority.h"

@implementation LOContentScheme

 - (SCCompoundURI *)resolve:(SCCompoundURI *)uri against:(SCCompoundURI *)reference {
    if ([uri.name hasPrefix:@"//"]) {
        // URI is absolute.
        return uri;
    }
    if ([uri.name hasPrefix:@"/"]) {
        // URI is an absolute path without an authority name.
        // Read authority name by splitting from '//{authority}/...'
        NSArray *parts = [reference.name componentsSeparatedByString:@"/"];
        NSString *authority = [parts count] > 1 ? parts[1] : @"";
        // Append URI path to the authority name.
        NSString *name = [NSString stringWithFormat:@"//%@%@", authority, uri.name];
        return [[SCCompoundURI alloc] initWithScheme:uri.scheme name:name];
    }
    // URI is a relative path, resolve to an absolute path against the reference.
    NSString *name = reference.name;
    if (![name hasSuffix:@"/"]) {
        // Unless the name ends with '/' (indicating a directory path) then strip
        // the last path component.
        name = [name stringByDeletingLastPathComponent];
    }
    // Append the relative path to the absolute reference path (which includes the
    // authority name at its start).
    name = [name stringByAppendingPathComponent:uri.name];
    return [[SCCompoundURI alloc] initWithScheme:uri.scheme name:name];
}

- (id)dereference:(SCCompoundURI *)uri parameters:(NSDictionary *)params {
    // Strip the leading '//'
    NSString *authName = [uri.name substringFromIndex:2];
    // Extract authority name from start.
    NSRange range = [authName rangeOfString:@"/"];
    authName = (range.location != NSNotFound)
        ? [authName substringToIndex:range.location]
        : authName;
    // Extract the content path.
    NSString *path = (range.location != NSNotFound)
        ? [authName substringFromIndex:range.location]
        : @"/";
    // Lookup the content authority.
    id<LOContentAuthority> authority = [[LOContentProvider getInstance] contentAuthorityForName:authName];
    if (authority) {
        // Request content from the authority.
        return [authority contentForPath:path parameters:params];
    }
    // Authority not found, return nil.
    return nil;
}

@end
