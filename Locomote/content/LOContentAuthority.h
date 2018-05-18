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
//  Created by Julian Goacher on 07/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOContentResponse.h"
#import "Q.h"

@class LOContentProvider;

/**
 * A protocol to be implemented by containers which are capable of providing data to content URIs and URLs.
 */
@protocol LOContentAuthority <NSObject>

/// The content provider the authority belongs to.
@property (nonatomic, weak) LOContentProvider *provider;

/// Handle an NSURLProtocol originating request.
- (void)handleURLProtocolRequest:(NSURLProtocol *)protocol;
/// Cancel an NSURLProtocol request currently being processed by the container.
- (void)cancelURLProtocolRequest:(NSURLProtocol *)protocol;
/// Test if the authority has content for the specified path.
- (BOOL)hasContentForPath:(NSString *)path parameters:(NSDictionary *)parameters;
/// Return the local cache location of the content with the specified path.
- (NSString *)localCacheLocationOfPath:(NSString *)path parameters:(NSDictionary *)parameters;
/// Return content for an internal content URI.
- (id)contentForPath:(NSString *)path parameters:(NSDictionary *)parameters;
/**
 * Synchronize the authority's content with its source.
 * Returns a deferred promise which resolves once the synchronize operation is complete.
 */
- (QPromise *)syncContent;

@end

