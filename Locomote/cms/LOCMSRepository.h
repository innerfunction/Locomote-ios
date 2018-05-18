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
//  Created by Julian Goacher on 13/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LORequestDispatcher.h"
#import "LOCMSRepoRequestHandler.h"
#import "LOCMSFileDB.h"
#import "LOCMSCommandProtocol.h"
#import "LOCMSSettings.h"
#import "LOCMSAuthenticationManager.h"
#import "SCHTTPClient.h"
#import "SCIOCObjectAware.h"
#import "SCIOCContainerAware.h"
#import "SCIOCConfigurationAware.h"
#import "SCMessageReceiver.h"
#import "Q.h"

@class LOCMSContentAuthority;

/**
 * A content authority which sources its content from a Locomote.sh content repository.
 */
@interface LOCMSRepository : NSObject <LORequestHandler, SCService, SCIOCObjectAware>

/// The path this repository is mounted under; i.e. a path in the form account/repo/~branch.
@property (nonatomic, strong) NSString *basePath;
/// The file database.
@property (nonatomic, strong) LOCMSFileDB *fileDB;
/// The HTTP client used for server requests.
@property (nonatomic, strong) SCHTTPClient *httpClient;
/// The authentication manager.
@property (nonatomic, strong) LOCMSAuthenticationManager *authManager;
/// The filesets defined for this authority.
@property (nonatomic, strong, readonly) NSDictionary *filesets;
/// The CMS settings (host / account / repo).
@property (nonatomic, strong) LOCMSSettings *cms;
/// The authority's scheduled command protocol.
@property (nonatomic, strong) LOCMSCommandProtocol *commandProtocol;
/// Repository content request handler.
@property (nonatomic, strong) LOCMSRepoRequestHandler *requestHandler;
/// The content authority this repository belongs to.
@property (nonatomic, strong) LOCMSContentAuthority *authority;

/// Synchronize the repository's content by downloading updates from the server.
- (QPromise *)syncContent;

@end

