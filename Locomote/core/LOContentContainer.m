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
#import "LOCMSContentAuthority.h"
#import "LOCMSRepository.h"
#import "LOCMSSettings.h"
#import "LOCMSAccountFormFactory.h"
#import "LOContentProvider.h"
#import "LOUserAccountManager.h"
#import "LOContentScheme.h"
#import "SCAppContainer.h"
#import "NSDictionary+SC.h"

@interface LOContentSource ()

- (void)registerSource;
- (void)completeSetup;
- (void)showLoginForm:(id)sender;

@end

@implementation LOContentContainer

+ (void)initialize {
    // Register the content scheme with the internal URI handler.
    id<SCURIHandler> uriHandler = [SCAppContainer getAppContainer].uriHandler;
    [uriHandler addHandler:[LOContentScheme new] forScheme:@"content"];
}

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

- (QPromise *)start {
    // Register all content sources with the content provider.
    for (LOContentSource *source in [_sources allValues]) {
        [source registerSource];
    }
    LOContentProvider *provider = [LOContentProvider getInstance];
    // Complete content provider setup.
    [provider completeSetup];
    // Complete setup of all sources.
    for (LOContentSource *source in [_sources allValues]) {
        [source completeSetup];
    }
    // Start the content provider.
    return [provider start];
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
        @"sources": [LOContentSource class]
    };
}

@end

@implementation LOContentSource

- (void)registerSource {
    // Create repo settings using the ref.
    LOCMSSettings *settings = [[LOCMSSettings alloc] initWithRef:_ref];
    // Create repo using the settings.
    _repository = [[LOCMSRepository alloc] initWithSettings:settings];
    // Check whether the content provider has a content authority for the repo.
    LOContentProvider *provider = [LOContentProvider getInstance];
    LOCMSContentAuthority *authority = (LOCMSContentAuthority *)[provider contentAuthorityForName:settings.authorityName];
    if (!authority) {
        // No matching content authority found, create a new one and add to the provider.
        authority = [LOCMSContentAuthority new];
        authority.authorityName = settings.authorityName;
        authority.uriHandler = [SCAppContainer getAppContainer].uriHandler;
        [provider setContentAuthority:authority withName:settings.authorityName];
    }
    // Add the repository to the content authority.
    [authority addRepository:_repository];
}

- (void)completeSetup {
    // Use the content reference as a realm name for user profile data.
    _userAccountManager.realmName = _ref;
    // Check whether a form factory is needed.
    if (_userAccountManager && !_accountFormFactory) {
        _accountFormFactory = [[LOCMSAccountFormFactory alloc] initWithRepository:_repository
                                                               userAccountManager:_userAccountManager];
    }
}

#pragma mark - SCMessageReceiver

- (BOOL)receiveMessage:(SCMessage *)message sender:(id)sender {
    if ([message hasName:@"logout"]) {
        [_userAccountManager logout];
        [self showLoginForm:sender];
        return YES;
    }
    if ([message hasName:@"password-reminder"]) {
        [_userAccountManager showPasswordReminder];
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

