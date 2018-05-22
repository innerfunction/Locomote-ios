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
#import "LOContentAuthority.h"
#import "LORequestDispatcher.h"
#import "LOCMSSettings.h"
#import "LOLocalCachePaths.h"
#import "LOCommandQueue.h"
#import "SCIOCTypeInspectable.h"
#import "SCURIHandling.h"

@class LOCMSRepository;

/**
 * A content authority backed by a Locomote content repository.
 * Depending on the host name used, the authority may be mapped to a single repository or
 * to multiple content repositories. For example, if configured to use the standard Locomote
 * host name (locomote.sh), then the authority may potentially map to any content repo hosted
 * on that domain, and individual repositories are supported by providing an {account}/{repo}
 * or {account}/{repo}/{branch} handler mapping. Alternatively, if a custom domain is used which
 * is mapped to a specific account and repository then the entire authority is mapped to that
 * one repo. The authority's 'setting' property is used to configure the default mapping details.
 */
@interface LOCMSContentAuthority : NSObject <LOContentAuthority, LORequestDispatcherHost, SCIOCTypeInspectable> {
    /// A set of live NSURL responses.
    NSMutableSet<NSURLProtocol *> *_liveResponses;
    /// A request dispatcher.
    LORequestDispatcher *_dispatcher;
}

/// The content provider.
@property (nonatomic, weak) LOContentProvider *provider;
/// The name of the authority that the class instance is bound to, e.g. the server host name.
@property (nonatomic, strong) NSString *authorityName;
/// A map of content repositories, keyed by account/repo or account/repo/branch.
@property (nonatomic, strong) NSDictionary<NSString *, LOCMSRepository *> *repositories;
/**
 * The authority's CMS settings. If the authority is potentially mapped to multiple repos
 * (see class comment above) then these may be partial settings, with missing values
 * provided by specific request handlers.
 */
@property (nonatomic, strong) LOCMSSettings *settings;
/// Path settings for locally cached content.
@property (nonatomic, strong) LOLocalCachePaths *localCachePaths;
/// Interval between content refreshes; in minutes.
@property (nonatomic, assign) float refreshInterval;
/// An optional URL handler.
@property (nonatomic, strong) id<SCURIHandler> uriHandler;
/// A command queue for executing content related commands.
@property (nonatomic, strong) LOCommandQueue *commandQueue;

/// Add a content repository to this authority.
- (void)addRepository:(LOCMSRepository *)repository;

@end
