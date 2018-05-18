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

#import "LORequestDispatcher.h"
#import "LOContentAuthority.h"
#import "IFFilePathPattern.h"
#import "NSDictionary+SC.h"

@implementation LORequestHandlerMapping

- (id)initWithPath:(NSString *)path handler:(id<LORequestHandler>)handler {
    self = [super init];
    self.path = path;
    self.handler = handler;
    return self;
}

@end

@implementation LORequestDispatcher

- (id)initWithHost:(id<LORequestDispatcherHost>)host {
    self = [super init];
    if (self) {
        _host = host;
    }
    return self;
}

- (void)dispatchRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {
    NSArray<LORequestHandlerMapping *> *mappings = _host.requestHandlers;
    // Iterate over the request handler mappings.
    for (LORequestHandlerMapping *mapping in mappings) {
        // Test the mapping path against the current path.
        NSDictionary *matches = [IFFilePathPattern matchPath:request.path usingPattern:mapping.path];
        if (matches) {
            // Match found, update the path parameters and dispatch the request.
            request.pathParameters = [request.pathParameters extendWith:matches];
            [mapping.handler handleRequest:request response:response];
            return;
        }
    }
    // No mapping found, return with path not found error.
    [response respondWithError:makePathNotFoundResponseError(request.path)];
}

@end
