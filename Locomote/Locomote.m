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
/**
 * Start content provider synchronization and wait for a result.
 * @param timeout The maximum time, in seconds, to wait for sync completion.
 *                If 0 or less then waits until synchronization is fully complete.
 * @return YES if synchronization completed.
 */
BOOL startAndWait(NSTimeInterval timeout);

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
    return [Locomote startWithTimeout:0];
}

+ (QPromise *)startWithTimeout:(NSTimeInterval)timeout {
    QPromise *promise = [QPromise new];
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL result = startAndWait( timeout );
        [promise resolve:[NSNumber numberWithBool:result]];
    });
    return promise;
}

+ (void)startWithCallback:(LOStartCallbackBlock)callback {
    [Locomote startWithTimeout:0 callback:callback];
}

+ (void)startWithTimeout:(NSTimeInterval)timeout callback:(LOStartCallbackBlock)callback {
    [Locomote startWithTimeout:timeout]
    .then( (id)^(NSNumber *ok) {
        callback( [ok boolValue] );
    })
    .fail( ^(id error) {
        callback( NO );
    });
}

+ (BOOL)startAndWait {
    return [Locomote startAndWaitWithTimeout:0];
}

+ (BOOL)startAndWaitWithTimeout:(NSTimeInterval)timeout {
    return startAndWait(timeout);
}

+ (NSBundle *)bundle {
    return nil;
}

+ (NSBundle *)bundleForAuthority:(NSString *)authorityName {
    return nil;
}

@end

BOOL startAndWait(NSTimeInterval timeout) {
    __block BOOL result = NO;
    NSCondition *checkpoint = [NSCondition new];
    LOContentProvider *provider = [LOContentProvider getInstance];
    [provider syncSources]
    .then( (id)^(NSNumber *ok) {
        result = [ok boolValue];
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

void logStartupError(id error) {
    NSLog(@"Locomote start error: %@", error );
}

@implementation UIImage (Locomote)

+ (UIImage *)locoImageWithPath:(NSString *)path {
    NSBundle *bundle = [Locomote bundle];
    return [UIImage imageNamed:path inBundle:bundle compatibleWithTraitCollection:nil];
}

@end