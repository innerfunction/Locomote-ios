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

#import "LOWPUserAccountManager.h"
#import "LOUserProfile.h"
#import "SSKeychain.h"
#import "SCHTTPClient.h"

@implementation LOWPUserAccountManager

@synthesize profileFieldNames=_profileFieldNames,
            standardFieldNames=_standardFieldNames,
            realmName=_realmName,
            authManager=_authManager;

- (id)init {
    self = [super init];
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    self.profileFieldNames = @[
        LOUserProfileProfileID,
        LOUserProfileUsername,
        LOUserProfileFirstName,
        LOUserProfileLastName,
        LOUserProfileEMail
    ];
    self.standardFieldNames = @{
        LOUserProfileFirstName:     @"first_name",
        LOUserProfileLastName:      @"last_name",
        LOUserProfileEMail:         @"user_email",
        LOUserProfileUsername:      @"user_login",
        LOUserProfilePassword:      @"user_pass",
        LOUserProfileConfirmPW:     @"confirm_pass",
        LOUserProfileProfileID:     @"ID"
    };
    return self;
}

- (BOOL)isLoggedIn {
    return [_authManager hasCredentials];
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password {
    [_authManager registerUsername:username password:password];
}

- (void)logout {
    [_authManager removeCredentials];
}

- (void)storeUserProfile:(NSDictionary *)values {
    // Read profile data from a 'profile' property in the data values.
    NSDictionary *profile = values[@"profile"];
    // Store standard profile values.
    for (NSString *field in _profileFieldNames) {
        NSString *key = [NSString stringWithFormat:@"%@/%@", _realmName, field];
        id value = profile[field];
        if (value) {
            [_userDefaults setValue:value forKey:key];
        }
    }
    // Search for and store any meta data values.
    NSMutableArray *metaKeys = [NSMutableArray new];
    for (NSString *key in [values keyEnumerator]) {
        if ([key hasPrefix:@"meta_"]) {
            id value = profile[key];
            NSString *storageKey = [NSString stringWithFormat:@"%@/%@", _realmName, key];
            if (value != [NSNull null]) {
                [_userDefaults setValue:value forKey:storageKey];
            }
            else {
                [_userDefaults removeObjectForKey:storageKey];
            }
            [metaKeys addObject:key];
        }
    }
    // Store list of meta-data keys.
    NSString *metaDataKeys = [metaKeys componentsJoinedByString:@","];
    NSString *storageKey = [NSString stringWithFormat:@"%@/metaDataKeys", _realmName];
    [_userDefaults setValue:metaDataKeys forKey:storageKey];
}

- (NSDictionary *)getUserProfile {
    NSMutableDictionary *values = [NSMutableDictionary new];
    NSString *storageKey = [NSString stringWithFormat:@"%@/%@", _realmName, LOUserProfileUsername];
    values[LOUserProfileUsername] = [_userDefaults stringForKey:storageKey];
    // Read standard profile fields.
    for (NSString *field in _profileFieldNames) {
        storageKey = [NSString stringWithFormat:@"%@/%@", _realmName, field];
        id value = [_userDefaults stringForKey:storageKey];
        if (value) {
            values[field] = value;
        }
    }
    // Read profile meta-data.
    storageKey = [NSString stringWithFormat:@"%@/metaDataKeys", _realmName];
    NSArray *metaDataKeys = [[_userDefaults stringForKey:storageKey] componentsSeparatedByString:@","];
    for (NSString *metaKey in metaDataKeys) {
        storageKey = [NSString stringWithFormat:@"%@/%@", _realmName, metaKey];
        id value = [_userDefaults stringForKey:storageKey];
        if (value) {
            values[metaKey] = value;
        }
    }
    // Return result.
    return values;
}

- (NSString *)authenticationURL {
    return [_baseURL stringByAppendingPathComponent:@"account/login"];
}

- (NSString *)newAccountURL {
    return [_baseURL stringByAppendingPathComponent:@"account/create"];
}

- (NSString *)accountProfileURL {
    return [_baseURL stringByAppendingPathComponent:@"account/profile"];
}

- (void)showPasswordReminder {
    // Fetch the password reminder URL from the server.
    NSString *url = [_baseURL stringByAppendingPathComponent:@"account/password-reminder"];
    SCHTTPClient *httpClient = [SCHTTPClient new];
    [httpClient get:url]
    .then((id)^(SCHTTPClientResponse *response) {
        id data = [response parseData];
        NSString *reminderURL = data[@"lost_password_url"];
        if (reminderURL) {
            // Open the URL in the device browser.
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:reminderURL]];
        }
        return nil;
    });
}

@end
