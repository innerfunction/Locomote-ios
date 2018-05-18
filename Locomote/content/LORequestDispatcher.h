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
#import "LOContentRequest.h"
#import "LOContentResponse.h"

/**
 * A content URL request handler.
 * Generates response content for a content request.
 */
@protocol LORequestHandler <NSObject>

/// Handle a request by writing data to the response.
- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response;

@end

/**
 * A mapping between a content URL request path pattern and a request handler.
 */
@interface LORequestHandlerMapping : NSObject

- (id)initWithPath:(NSString *)path handler:(id<LORequestHandler>)handler;

/// A request path or path pattern.
@property (nonatomic, strong) NSString *path;
/// A handler for requests matching the request path pattern.
@property (nonatomic, strong) id<LORequestHandler> handler;

@end

/**
 * A protocol implemented by classes that contain request dispatchers.
 */
@protocol LORequestDispatcherHost <NSObject>

/// A list of request handler mappings.
@property (nonatomic, strong) NSArray<LORequestHandlerMapping *> *requestHandlers;

@end

/**
 * A class for dispatching content URL requests to an appropriate handler.
 * Handlers are identified by mappings which map a request path or pattern to a
 * handler instance.
 */
@interface LORequestDispatcher : NSObject {
    id<LORequestDispatcherHost> _host;
}

/// Initialize the dispatcher with a host which provides a list of handler mappings.
- (id)initWithHost:(id<LORequestDispatcherHost>)host;
/// Dispatch a request.
- (void)dispatchRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response;

@end
