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

#import <UIKit/UIKit.h>
#import "Q.h"

//! Project version number for Locomote-ios.
FOUNDATION_EXPORT double Locomote_iosVersionNumber;

//! Project version string for Locomote-ios.
FOUNDATION_EXPORT const unsigned char Locomote_iosVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <Locomote_ios/PublicHeader.h>

typedef void (^LOStartCallbackBlock) (BOOL ok);

@interface Locomote : NSObject

/**
 * Add the configuration for a content repository to the list of sources used by the Locomote content provider.
 * @param config    A content repository configuration. Can be specified as a string or an object literal.
 */
+ (void)addRepository:(id)config;
/**
 * Start the Locomote content provider.
 * Starting the provider will cause it to synchronize each source content repository with the remote server.
 * The method returns immediately with a deferred promise which resolves once all source repositories have
 * synchronized.
 */
+ (QPromise *)start;
/**
 * Start the Locomote content provider.
 * Starting the provider will cause it to synchronize each source content repository with the remote server.
 * The method returns immediately with a deferred promise which resolves once all source repositories have
 * synchronized, or when the timeout interval has elapsed, whichever occurs first.
 * The promise will resolve with a value of _YES_ (_true_) if content synchronization has completed, or
 * _NO_ (_false_) if content is still synchronizing when the timeout completes.
 */
+ (QPromise *)startWithTimeout:(NSTimeInterval)timeout;
/**
 * Start the Locomote content provider.
 * This method is provided as an alternative to the [Locomote start] method. The method will return immediately
 * whilst the source content repositories synchronize in the background. the callback block will be invoked
 * once all source content repositories have synchronized.
 */
+ (void)startWithCallback:(LOStartCallbackBlock)callback;
/**
 * Start the Locomote content provider.
 * This method is provided as an alternative to the [Locomote startWithTimeout:] method. The method will return
 * immediately whilst the source content repositories synchronize in the background. the callback block will be
 * invoked once all source content repositories have synchronized, or when the timeout interval has elapsed,
 * whichever occurs first. The callback block is passed a _BOOL_ value indicating whether content synchronization
 * has completed when the callback is invoked.
 */
+ (void)startWithTimeout:(NSTimeInterval)timeout callback:(LOStartCallbackBlock)callback;
/**
 * Start the Locomote content provider.
 * Starts the content provider and blocks until all content repositories have synchronized.
 */
+ (BOOL)startAndWait;
/**
 * Start the Locomote content provider.
 * Starts the content provider and blocks until all content repositories have synchronized, or until the
 * specified timeout delay has elapsed. Repositories will continue to synchronize in the background if
 * the timeout interval is exceeded.
 */
+ (BOOL)startAndWaitWithTimeout:(NSTimeInterval)timeout;
/**
 * Get the default Locomote resource bundle.
 * The result can be used as a stand-in replacement for [NSBundle mainBundle]. File resources can be referenced
 * by path; resources within specific content repositories must have the authority name of that repository
 * prefixed to their path.
 */
+ (NSBundle *)bundle;

@end

@interface UIImage (Locomote)

/**
 * Load an image from a Locomote.sh path.
 * The image path has to include an authority name prefix.
 */
+ (UIImage *)locoImageWithPath:(NSString *)path;

@end
