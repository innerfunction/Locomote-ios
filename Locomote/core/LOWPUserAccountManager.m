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

@implementation LOWPUserAccountManager

@synthesize profileFieldNames=_profileFieldNames,
            standardFieldNames=_standardFieldNames,
            realmName=_realmName;

- (id)init {
    self = [super init];
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    self.profileFieldNames = @[@"ID", @"first_name", @"last_name", @"user_email"];
    self.standardFieldNames = @{
        LOUserAccountFirstName:     @"first_name",
        LOUserAccountLastName:      @"last_name",
        LOUserAccountEMail:         @"user_email",
        LOUserAccountUsername:      @"user_login",
        LOUserAccountPassword:      @"user_pass",
        LOUserAccountConfirmPW:     @"confirm_pass",
        LOUserAccountProfileID:     @"ID"
    };
    return self;
}

- (NSString *)authenticationURL {
    return AppendPathToURL(_container.feedURL, @"account/login");
}

- (NSString *)newAccountURL {
    return AppendPathToURL(_container.feedURL, @"account/create");
}

- (NSString *)accountProfileURL {
    return AppendPathToURL(_container.feedURL, @"account/profile");
}

- (BOOL)isAuthenticated {
    NSString *key = [NSString stringWithFormat:@"%@/%@", _realmName, @"logged-in"];
    return [_userDefaults boolForKey:key];
}

- (void)storeUserCredentials:(NSDictionary *)values {
    NSString *username = values[@"user_login"];
    NSString *password = values[@"user_pass"];
    // NOTE this will work for all forms - login, create account + update profile. In the latter case, if the
    // password is not updated then password will be empty and the keystore won't be updated.
    if ([username length] > 0 && [password length] > 0) {
        [SSKeychain setPassword:password forService:_container.wpRealm account:username];
        NSString *key = [NSString stringWithFormat:@"%@/%@", _realmName, @"logged-in"];
        [_userDefaults setValue:@YES forKey:key];
        // TODO: Need to review whether this is best practice.
        key = [NSString stringWithFormat:@"%@/%@", _realmName, @"user_login"];
        [_userDefaults setValue:username forKey:key];
    }
}

- (void)storeUserProfile:(NSDictionary *)values {
    // Store standard profile values.
    for (NSString *field in _profileFieldNames) {
        NSString *key = [NSString stringWithFormat:@"%@/%@", _realmName, field];
        id value = values[field];
        if (value) {
            [_userDefaults setValue:value forKey:key];
        }
    }
    // Search for and store any meta data values.
    NSMutableArray *metaKeys = [NSMutableArray new];
    for (NSString *key in [values keyEnumerator]) {
        if ([key hasPrefix:@"meta_"]) {
            id value = values[key];
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
    NSString *storageKey = [NSString stringWithFormat:@"%@/%@", _realmName, @"user_login"];
    values[@"user_login"] = [_userDefaults stringForKey:storageKey];
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

- (NSString *)getUsername {
    NSString *storageKey = [NSString stringWithFormat:@"%@/%@", _realmName, @"user_login"];
    return [_userDefaults stringForKey:storageKey];
}

- (void)logout {
    NSString *key = [NSString stringWithFormat:@"%@/%@", _realmName, @"logged-in"];
    [_userDefaults setValue:@NO forKey:key];
}

- (void)showPasswordReminder {
    // Fetch the password reminder URL from the server.
    NSString *url = [_container.feedURL stringByAppendingPathComponent:@"account/password-reminder"];
    [_container.httpClient get:url]
    .then((id)^(IFHTTPClientResponse *response) {
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
