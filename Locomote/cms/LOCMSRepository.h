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
#import "LOAbstractContentAuthority.h"
#import "LOCMSFileDB.h"
#import "LOCMSFilesetCategoryPathRoot.h"
#import "LOCMSCommandProtocol.h"
#import "LOCMSSettings.h"
#import "LOCMSAuthenticationManager.h"
#import "SCHTTPClient.h"
#import "SCIOCObjectAware.h"
#import "SCIOCContainerAware.h"
#import "SCIOCConfigurationAware.h"
#import "SCMessageReceiver.h"
#import "SCJSONData.h"
#import "Q.h"

/**
 * A content authority which sources its content from a Locomote.sh content repository.
 */
@interface LOCMSRepository : LOAbstractContentAuthority <SCService>

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
/// A map of available content record type converters.
@property (nonatomic, strong) NSDictionary *recordTypes;
/// A map of available content query type converters.
@property (nonatomic, strong) NSDictionary *queryTypes;
/// The authority's scheduled command protocol.
@property (nonatomic, strong) LOCMSCommandProtocol *commandProtocol;

- (id)initWithSettings:(LOCMSSettings *)settings;

@end

