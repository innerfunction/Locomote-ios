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
////  Created by Julian Goacher on 20/10/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>

/// A class representing a Locomote content repository's settings.
@interface LOCMSSettings : NSObject

/// The server host name.
@property (nonatomic, strong) NSString *host;
/// The server port number.
@property (nonatomic, assign) NSInteger port;
/// The base path on the server for accessing the CMS.
@property (nonatomic, strong) NSString *basePath;
/// The  HTTP authentication realm.
@property (nonatomic, strong) NSString *authRealm;
/// The server protocol, e.g. HTTP or HTTPS.
@property (nonatomic, strong) NSString *protocol;
/// A username for accessing the CMS.
@property (nonatomic, strong) NSString *username;
/// A password to go with the username.
@property (nonatomic, strong) NSString *password;
/// An authority name, derived from the settings values.
@property (nonatomic, strong) NSString *authorityName;
/// Return the URL for login authentication.
@property (nonatomic, readonly) NSString *authenticationURL;
/// Return the URL for the updates feed.
@property (nonatomic, readonly) NSString *updatesURL;

/**
 * Initialize settings with a string reference.
 * The string ref can be a full or partial URL or path, specifing some or all of different setting fields.
 * The reference takes the following format:
 *
 *      (protocol:)?(username : password @)?((host (: port)? /)? account / repo (/ branch)?
 *
 * Examples of possible valid references are:
 *  - https://locomote.sh/cms/2.0/account/repo  Full URL form.
 *  - account/repo:         Connect to account and repo on locomote.sh; equivalent to previous example.
 *  - account/repo/branch:  Connect to account, repo and branch on locomote.sh
 *  - domain.sh/repo        Connect to repo hosted under custom domain.
 */
- (id)initWithRef:(NSString *)ref;

/// Return the URL for downloading a fileset of the specified category.
- (NSString *)urlForFileset:(NSString *)category;
/// Return the URL for downloading a file at the specified path.
- (NSString *)urlForFile:(NSString *)path;
/// Get the API's base URL. Used as the HTTP authentication protection space.
- (NSString *)apiBaseURL;

@end
