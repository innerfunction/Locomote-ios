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

#import "Locomote.h"
#import "LOCMSSettings.h"
#import "LOCMSRepository.h"
#import "LOContentProvider.h"

void logStartupError(id error);

@implementation Locomote

+ (void)addRepository:(id)config {
    LOCMSSettings *settings = nil;
    if ([config isKindOfClass:[NSString class]]) {
        settings = [[LOCMSSettings alloc] initWithRef:(NSString *)config];
    }
    else if ([config isKindOfClass:[NSDictionary class]]) {
        settings = [[LOCMSSettings alloc] initWithSettings:(NSDictionary *)config];
    }
    if (settings) {
        LOCMSRepository *repo = [[LOCMSRepository alloc] initWithSettings:settings];
        LOContentProvider *provider = [LOContentProvider getInstance];
        [provider setContentAuthority:repo withName:name]; // TODO What is the authority name?
    }
    else {
        // Invalid repository config.
    }
}

+ (QPromise *)start {
    return [Q resolve:nil];
}

+ (void)startWithCallback:(LOStartCallbackBlock)callback {
    [Locomote start]
    .then( (id)^(BOOL ok) {
        callback( ok );
    })
    .fail( ^(id error) {
        callback( NO );
        logStartupError( error );
    });
}

+ (BOOL)startInForeground {
    return [Locomote startInForegroundWithTimeout:0];
}

+ (BOOL)startInForegroundWithTimeout:(NSTimeInterval)timeout {
    __block BOOL result = NO;
    NSCondition *checkpoint = [NSCondition new];
    [self start]
    .then( (id)^(BOOL ok) {
        result = ok;
        [checkpoint signal];
        return nil;
    })
    .fail( ^(id error) {
        result = NO;
        [checkpoint signal];
        logStartupError( error );
    });
    if (timeout > 0) {
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:timeout];
        [checkpoint waitUntilDate:until];
    }
    else {
        [checkpoint wait];
    }
    return result;
}

+ (NSBundle *)bundle {
    return nil;
}

+ (NSBundle *)bundleForAuthority:(NSString *)authorityName {
    return nil;
}

@end

@implementation UIImage (Locomote)

+ (UIImage *)locoImageWithPath:(NSString *)path {
    NSBundle *bundle = [Locomote bundle];
    return [UIImage imageNamed:path inBundle:bundle compatibleWithTraitCollection:nil];
}

@end