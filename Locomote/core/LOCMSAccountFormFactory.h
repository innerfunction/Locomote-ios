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
//  Created by Julian Goacher on 22/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOCMSRepository.h"
#import "LOCMSAuthenticationManager.h"
#import "SCIOCObjectFactoryBase.h"
#import "SCViewBehaviourObject.h"
#import "SCHTTPClient.h"

@protocol LOUserProfileManager;

/// A factory class for generating user account related forms.
@interface LOCMSAccountFormFactory : SCIOCObjectFactoryBase

@property (nonatomic, weak) LOCMSRepository *repository;
@property (nonatomic, weak) id<LOUserProfileManager> userProfileManager;
@property (nonatomic, weak) SCHTTPClient *httpClient;
@property (nonatomic, strong) NSDictionary *stdParams;

- (id)initWithRepository:(LOCMSRepository *)repository userProfileManager:(id<LOUserProfileManager>)userProfileManager;

@end

@interface LOLoginBehaviour : SCViewBehaviourObject

- (id)initWithAuthenticationManager:(LOCMSAuthenticationManager *)authManager loginAction:(NSString *)loginAction;

@property (nonatomic, weak) LOCMSAuthenticationManager *authManager;
@property (nonatomic, strong) NSString *loginAction;

@end
