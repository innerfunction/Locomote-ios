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

#import "LOContentProvider.h"
#import "LOContentAuthority.h"
#import "LOContentURLProtocol.h"
#import "NSDictionary+SC.h"

#define NamePrefix (@"locomote")

@interface LOContentProvider ()

- (NSDictionary *)parseContentPath:(NSString *)path;

@end

@implementation LOContentProvider

- (id)init {
    self = [super init];
    if (self) {
    
        self.authorities = @{};
        
        // NOTES on staging and cache paths:
        // * Freshly downloaded content is stored under the staging path until the download is complete,
        //   after which it is deployed to the appropriate cache path and deleted from the staging location.
        //   The staging path is placed under NSApplicationSupportDirectory to avoid it being deleted by
        //   the system mid-download, in the case where the system needs to free up disk space.
        // * App content is deployed under NSApplicationSupportDirectory to avoid it being cleared by the system.
        // * All other content is deployed under NSCachesDirectory, where the system may remove it if it needs to
        //   recover disk space. If this happens then the content provider will attempt to re-downloaded the content
        //   again, if and when it's needed.
        // See:
        // * http://developer.apple.com/library/ios/#documentation/FileManagement/Conceptual/FileSystemProgrammingGUide/FileSystemOverview/FileSystemOverview.html
        //
        // * https://developer.apple.com/library/ios/#documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/PerformanceTuning/PerformanceTuning.html#//apple_ref/doc/uid/TP40007072-CH8-SW8
        //
        
        self.localCachePaths = [LOLocalCachePaths new];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [paths objectAtIndex:0];
        NSString *dirName = [NSString stringWithFormat:@"%@.staging", NamePrefix];
        _localCachePaths.stagingPath = [cachePath stringByAppendingPathComponent:dirName];
        dirName = [NSString stringWithFormat:@"%@.app", NamePrefix];
        _localCachePaths.appCachePath = [cachePath stringByAppendingPathComponent:dirName];
        
        // Switch cache path for content location.
        paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        cachePath = [paths objectAtIndex:0];
        dirName = [NSString stringWithFormat:@"%@.content", NamePrefix];
        _localCachePaths.contentCachePath = [cachePath stringByAppendingPathComponent:dirName];

        // Packaged content stored in a folder named 'packaged-content'.
        _localCachePaths.packagedContentPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"packaged-content"];
        
    }
    return self;
}

- (void)setAuthorities:(NSDictionary *)authorities {
    _authorities = authorities;
    for (id name in [authorities keyEnumerator]) {
        id<LOContentAuthority> authority = _authorities[name];
        authority.provider = self;
    }
}

- (void)setContentAuthority:(id<LOContentAuthority>)authority withName:(NSString *)name {
    _authorities = [_authorities dictionaryWithAddedObject:authority forKey:name];
    authority.provider = self;
}

- (id<LOContentAuthority>)contentAuthorityForName:(NSString *)name {
    return _authorities[name];
}

- (void)completeSetup {
    for (id<LOContentAuthority> authority in [_authorities allValues]) {
        [authority completeSetup];
    }
}

- (QPromise *)start {
    // Register the content: protocol.
    [NSURLProtocol registerClass:[LOContentURLProtocol class]];
    // Start all authorities.
    NSMutableArray *promises = [NSMutableArray new];
    for (id key in _authorities) {
        id<LOContentAuthority> authority = _authorities[key];
        [promises addObject:[authority start]];
    }
    return [Q all:promises];
}

- (QPromise *)syncAuthorities {
    NSMutableArray *promises = [NSMutableArray new];
    for (id key in _authorities) {
        id<LOContentAuthority> authority = _authorities[key];
        [promises addObject:[authority syncContent]];
    }
    return [Q all:promises];
}

- (BOOL)hasContentForPath:(NSString *)path {
    NSDictionary *parts = [self parseContentPath:path];
    id<LOContentAuthority> authority = [self contentAuthorityForName:parts[@"authority"]];
    if (authority) {
        return [authority hasContentForPath:parts[@"part"] parameters:@{}];
    }
    return NO;
}

- (NSString *)localCacheLocationOfPath:(NSString *)path {
    NSDictionary *parts = [self parseContentPath:path];
    id<LOContentAuthority> authority = [self contentAuthorityForName:parts[@"authority"]];
    if (authority) {
        return [authority localCacheLocationOfPath:parts[@"part"] parameters:@{}];
    }
    return nil;
}

+ (LOContentProvider *)getInstance {
    static LOContentProvider *instance;
    if (instance == nil) {
        instance = [LOContentProvider new];
    }
    return instance;
}

#pragma mark - SCMessageRouter

- (BOOL)routeMessage:(SCMessage *)message sender:(id)sender {
    BOOL routed = NO;
    NSString *authorityName = [message targetHead];
    id authority = [self contentAuthorityForName:authorityName];
    if (authority) {
        if ([authority conformsToProtocol:@protocol(SCMessageReceiver)]) {
            routed = [(id<SCMessageReceiver>)authority receiveMessage:message sender:sender];
        }
    }
    return routed;
}

#pragma mark - SCMessageReceiver

- (BOOL)receiveMessage:(SCMessage *)message sender:(id)sender {
    return NO;
}

#pragma mark - SCIOCSingleton

+ (id)iocSingleton {
    return [LOContentProvider getInstance];
}

#pragma mark - private

- (NSDictionary *)parseContentPath:(NSString *)path {
    NSRange range = [path rangeOfString:@"/"];
    if (range.location != NSNotFound) {
        return @{
            @"authority":   [path substringToIndex:range.location],
            @"path":        [path substringFromIndex:range.location + 1]
         };
    }
    return @{ @"authority": path };
}

@end
