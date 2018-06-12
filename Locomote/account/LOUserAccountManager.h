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
#import "LOUserProfile.h"
#import "LOHTTPAuthenticationManager.h"

/**
 * A protocol for managing user profile details.
 * The protocol should be implemented by classes providing functionality for authenticating
 * against a specific server-side authentication method or scheme.
 */
@protocol LOUserAccountManager <NSObject>

/// Get the URL used to authenticate login requests.
@property (nonatomic, readonly) NSString *authenticationURL;
/// Get the URL used to create new user accounts.
@property (nonatomic, readonly) NSString *newAccountURL;
/// Get the URL used to return account profile details.
@property (nonatomic, readonly) NSString *accountProfileURL;
/// Return a list of the field names to be stored in the user profile.
@property (nonatomic, strong) NSArray<NSString *> *profileFieldNames;
/// Return a dictionary of the standard field names used in login forms etc.
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *standardFieldNames;
/// A user account realm name.
@property (nonatomic, strong) NSString *realmName;
/// The HTTP authentication manager to use with the account manager.
@property (nonatomic, strong) LOHTTPAuthenticationManager *authManager;

/// Test if there is a current logged-in user account.
- (BOOL)isLoggedIn;
/// Set the account state to logged-in with the specified username and password.
- (void)loginWithUsername:(NSString *)username password:(NSString *)password;
/// Change the account state from logged-in to logged-out.
- (void)logout;
/// Store a user's profile data.
- (void)storeUserProfile:(NSDictionary *)values;
/// Get a user's stored profile data.
- (NSDictionary *)getUserProfile;
/// Do something to show a password reminder screen to the user.
- (void)showPasswordReminder;

@end
