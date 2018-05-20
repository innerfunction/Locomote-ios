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
//  Created by Julian Goacher on 30/04/2017.
//  Copyright © 2017 Locomote.sh. All rights reserved.
//

#import "Locomote.h"
#import "LOCMSSettings.h"
#import "LOCMSRepository.h"
#import "LOContentProvider.h"
#import "LOBundle.h"

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
        [provider setContentAuthority:repo withName:settings.authorityName];
    }
    else {
        // Invalid repository config.
        NSLog(@"ERROR: Locomote repository config must be NSString or NSDictionary type; %@ provided", [config class]);
    }
}

+ (QPromise *)start {
    return [Locomote startWithTimeout:0];
}

+ (QPromise *)startWithTimeout:(NSTimeInterval)timeout {
    QPromise *promise = [QPromise new];
    // Execute the start operation on a background thread.
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
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
    // Execute the start operation on the current thread.
    return startAndWait( timeout );
}

+ (NSBundle *)bundle {
    return [LOBundle locomoteBundle];
}

@end

BOOL startAndWait(NSTimeInterval timeout) {
    __block NSNumber *result = nil;
    NSCondition *checkpoint = [NSCondition new];
    LOContentProvider *provider = [LOContentProvider getInstance];
    [provider syncAuthorities]
    .then( (id)^(NSNumber *ok) {
        // Signal the result.
        [checkpoint lock];
        result = ok;
        [checkpoint signal];
        [checkpoint unlock];
        return nil;
    })
    .fail( ^(id error) {
        // Signal a startup error.
        [checkpoint lock];
        result = [NSNumber numberWithBool:NO];
        [checkpoint signal];
        [checkpoint unlock];
        NSLog(@"ERROR: Locomote start failure %@", error );
    });
    // Wait for the result if none already.
    [checkpoint lock];
    if (result == nil) {
        if (timeout > 0) {
            NSDate *until = [NSDate dateWithTimeIntervalSinceNow:timeout];
            [checkpoint waitUntilDate:until];
        }
        else {
            [checkpoint wait];
        }
    }
    [checkpoint unlock];
    return [result boolValue];
}

@implementation UIImage (Locomote)

+ (UIImage *)locomoteImageWithPath:(NSString *)path {
    NSBundle *bundle = [Locomote bundle];
    return [UIImage imageNamed:path inBundle:bundle compatibleWithTraitCollection:nil];
}

@end

@implementation NSBundle (Locomote)

+ (NSBundle *)locomoteBundle {
    return [LOBundle locomoteBundle];
}

@end
