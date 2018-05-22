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
#import "LOUserProfileManager.h"
#import "LOCMSAccountFormFactory.h"
#import "SCAppContainer.h"
#import "NSDictionary+SC.h"

@interface LOContentSource ()

- (void)showLoginForm:(id)sender;

@end

@implementation LOContentContainer

- (id)init {
    self = [super init];
    self.sources = @{};
    return self;
}

- (void)addRepository:(NSString *)ref {
    // NOTE - this method intended for use by Locomote.m; user account manager not supported in this usage pattern.
    LOContentSource *source = [LOContentSource new];
    source.ref = ref;
    _sources = [_sources dictionaryWithAddedObject:source forKey:ref];
}

- (void)setup {
    // Complete setup of all content sources.
    for (LOContentSource *source in [_sources allValues]) {
        [source setup];
    }
}

- (QPromise *)start {
    // Complete setup and then start the content provider.
    [self setup];
    return [[LOContentProvider getInstance] start];
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
        @"source": [LOContentSource class]
    };
}

@end

@implementation LOContentSource

- (void)setup {
    // Create repo settings using the ref.
    LOCMSSettings *settings = [[LOCMSSettings alloc] initWithRef:_ref];
    // Create repo using the settings.
    _repository   = [[LOCMSRepository alloc] initWithSettings:settings];
    // Check whether the content provider has a content authority for the repo.
    LOContentProvider *provider = [LOContentProvider getInstance];
    id<LOContentAuthority> authority = [provider contentAuthorityForName:settings.authorityName];
    if (!authority) {
        // No matching content authority found, create a new one and add to the provider.
        authority = [LOCMSContentAuthority new];
        [provider setContentAuthority:authority withName:settings.authorityName];
    }
    // Add the repository to the content authority.
    [(LOCMSContentAuthority *)authority addRepository:_repository];
    // Complete the repository setup.
    [_repository setup];
    // Use the content reference as a realm name for user profile data.
    _userProfileManager.realmName = _ref;
    // Check whether a form factory is needed.
    if (_userProfileManager && !_accountFormFactory) {
        _accountFormFactory = [[LOCMSAccountFormFactory alloc] initWithRepository:_repository
                                                               userProfileManager:_userProfileManager];
    }
}

#pragma mark - SCMessageReceiver

- (BOOL)receiveMessage:(SCMessage *)message sender:(id)sender {
    if ([message hasName:@"logout"]) {
        [_repository.authManager removeCredentials];
        [self showLoginForm:sender];
        return YES;
    }
    if ([message hasName:@"password-reminder"]) {
        [_userProfileManager showPasswordReminder];
        return YES;
    }
    if ([message hasName:@"show-login"]) {
        [self showLoginForm:sender];
        return YES;
    }
    return NO;
}

#pragma mark - private

- (void)showLoginForm:(id)sender {
    [[SCAppContainer getAppContainer] postMessage:_showLoginAction sender:sender];
}

@end

