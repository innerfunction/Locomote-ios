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
//  Created by Julian Goacher on 17/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A protocol for accessing functionality for writing responses to content URL and URI requests.
 */
@protocol LOContentResponse <NSObject>

/**
 * Respond with content data.
 * Writes the response data in full and then ends the response.
 */
- (void)respondWithData:(NSData *)data mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)policy;
/// Start a content response. Note that the [done] method must be called on completion.
- (void)respondWithMimeType:(NSString *)mimeType cacheStoragePolicy:(NSURLCacheStoragePolicy)policy;
/**
 * Write content data to the response.
 * The response must be started with a call to the [respondWithMimeType: cacheStoragePolicy:] method before
 * this method is called. This method may then be called as many times as necessary to write the content data
 * in full. The [done] method must be called once all data is written.
 */
- (void)sendData:(NSData *)data;
/// End a content response.
- (void)done;
/// Respond with string data of the specified MIME type.
- (void)respondWithStringData:(NSString *)data mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)cachePolicy;
/// Respond with JSON data.
- (void)respondWithJSONData:(id)data cachePolicy:(NSURLCacheStoragePolicy)cachePolicy;
/// Respond with file data of the specified MIME type.
- (void)respondWithFileData:(NSString *)filepath mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)cachePolicy;
/**
 * Respond with an error indicating why the request couldn't be resolved.
 * This method should be called instead of one of the respondWithMimeType* methods defined on this protocol, whenever
 * an error occurs that prevents the request data from being resolved. Calling this method completes the response.
 */
- (void)respondWithError:(NSError *)error;

@end

/// Make a file not found response error.
NSError *makePathNotFoundResponseError(NSString *path);

/// Make an invalid request path error.
NSError *makeInvalidPathResponseError(NSString *path);

/// Make an unsupported type error.
NSError *makeUnsupportedTypeResponseError(NSString *type);

/// Make an invalid fileset category error.
NSError *makeInvalidCategoryResponseError(NSString *category);

