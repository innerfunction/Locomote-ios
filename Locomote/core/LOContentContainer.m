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

#import "LOContentContainer.h"
#import "LOCMSRepository.h"
#import "LOCMSSettings.h"
#import "LOContentProvider.h"
#import "LOUserAccountManager.h"
#import "LOAccountFormFactory.h"
#import "SCAppContainer.h"
#import "NSDictionary+SC.h"

@implementation LOContentContainer

- (id)init {
    self = [super init];
    self.content = @{};
    return self;
}

- (void)addRepository:(NSString *)ref {
    // NOTE - this method intended for use by Locomote.m; user account manager not supported in this usage pattern.
    LOContentSource *source = [LOContentSource new];
    source.ref = ref;
    _content = [_content dictionaryWithAddedObject:source forKey:ref];
}

- (void)setup {
    // Complete setup of all content sources.
    for (LOContentSource *source in [_content allValues]) {
        [source setup];
    }
}

- (QPromise *)start {
    // Complete setup and then start the content provider.
    [self setup];
    [[LOContentProvider getInstance] start];
}

+ (LOContentContainer *)getInstance {
    static LOContentContainer *instance;
    if (instance == nil) {
        instance = [LOContentContainer new];
    }
    return instance;
}

#pragma mark - SCService

- (void)startService {
    [self start];
}

#pragma mark - SCIOCTypeInspectable

- (NSDictionary *)collectionMemberTypeInfo {
    return @{
        @"content": [LOContentSource class]
    };
}

@end

@implementation LOContentSource

- (void)setup {
    // Create repo settings using the ref.
    LOCMSSettings *settings = [[LOCMSSettings alloc] initWithRef:_ref];
    // Create repo using the settings.
    LOCMSRepository *repo   = [[LOCMSRepository alloc] initWithSettings:settings];
    // Check whether the content provider has a content authority for the repo.
    LOContentProvider *provider = [LOContentProvider getInstance];
    id<LOContentAuthority> authority = [provider contentAuthorityForName:settings.authorityName];
    if (!authority) {
        // No matching content authority found, create a new one and add to the provider.
        authority = [LOCMSContentAuthority new];
        [provider setContentAuthority:authority withName:settings.authorityName];
    }
    // Add the repository to the content authority.
    [(LOCMSContentAuthority *)authority addRepository:repo];
    // Use the content reference as a realm name for user account data.
    _userAccountManager.realmName = _ref;
    // Check whether a form factory is needed.
    if (_userAccountManager && !_accountFormFactory) {
        _accountFormFactory = [[LOAccountFormFactory alloc] initWithUserAccountManager:_userAccountManager
                                                                            httpClient:repo.httpClient];
    }
}

@end

