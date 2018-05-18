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
//  Created by Julian Goacher on 20/10/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOCMSSettings.h"

#define DefaultAPIVersion   (@"0.2")
#define DefaultAPIRoot      (@"cms")
#define DefaultAPIProtocol  (@"https")
#define AuthRealmPrefix     (@"sh.locomote")

@interface LOCMSSettings()

- (NSString *)pathForResource:(NSString *)resourceName trailing:(NSString *)trailing;
- (NSString *)urlForPath:(NSString *)path;

@end

@implementation LOCMSSettings

- (id)init {
    self = [super init];
    if (self) {
        self.pathRoot = [DefaultAPIRoot stringByAppendingPathComponent:DefaultAPIVersion];
        self.protocol = DefaultAPIProtocol;
        self.port = 0;
    }
    return self;
}

- (id)initWithRef:(NSString *)ref {

    // Ref is a whole or partial, absolute or relative URL which is resolved against
    // the default repository base URL as defined in this class (e.g. https://locomote.sh/cms/0.2/).
    NSURL *baseURL = [NSURL URLWithString:[self urlForPath:@"/"]];
    NSURL *repoURL = [NSURL URLWithString:ref relativeToURL:baseURL];
    
    // Extract core properties from the URL and use to initialize the settings object.
    id account = nil, repo = nil;
    if ([repoURL.pathComponents count] > 3) {
        // First two components are API root & version, e.g. 'cms' & '0.2'
        account = repoURL.pathComponents[2];
        repo = repoURL.pathComponents[3];
    }
    self = [self initWithHost:repoURL.host
                      account:account
                   repository:repo
                     username:repoURL.user
                     password:repoURL.password];
    
    // Complete configuration with non-core properties.
    self.protocol = repoURL.scheme;
    self.port = [repoURL.port integerValue];
    if ([repoURL.pathComponents count] > 4) {
        self.branch = repoURL.pathComponents[4];
        self.authorityName = [NSString stringWithFormat:@"%@.%@", self.authorityName, self.branch ];
    }
    
    // Allow the URL fragment to override the default authority name.
    if (repoURL.fragment) {
        self.authorityName = repoURL.fragment;
    }
    
    return self;
}

- (id)initWithSettings:(NSDictionary *)settings {

    self = [self initWithHost:settings[@"host"]
                      account:settings[@"account"]
                   repository:settings[@"repo"]
                     username:settings[@"username"]
                     password:settings[@"password"]];

    // Test for branch setting.
    id branch = settings[@"branch"];
    if (branch) {
        self.branch = branch;
        self.authorityName = [NSString stringWithFormat:@"%@.%@", self.authorityName, branch ];
    }
    
    // If a specific authority name is provided then override the default name.
    NSString *authorityName = settings[@"authorityName"];
    if (authorityName) {
        self.authorityName = authorityName;
    }
    
    return self;
}

- (id)initWithHost:(NSString *)host account:(NSString *)account repository:(NSString *)repo username:(NSString *)username password:(NSString *)password {
    self = [self init];
    self.host = host;
    self.account = account;
    self.repo = repo;
    self.username = username;
    self.password = password;
    self.authorityName = [NSString stringWithFormat:@"%@.%@", account, repo ];
    return self;
}

- (NSString *)authRealm {
    if (!_authRealm) {
        NSString *branch = _branch ? _branch : @"master";
        _authRealm = [NSString stringWithFormat:@"%@/%@/%@/%@", AuthRealmPrefix, _account, _repo, branch];
    }
    return _authRealm;
}

- (NSString *)urlForAuthentication {
    return [self urlForPath:[self pathForResource:@"authenticate" trailing:nil]];
}

- (NSString *)urlForUpdates {
    return [self urlForPath:[self pathForResource:@"updates" trailing:nil]];
}

- (NSString *)urlForFileset:(NSString *)category {
    return [self urlForPath:[self pathForResource:@"filesets" trailing:category]];
}

- (NSString *)urlForFile:(NSString *)path {
    return [self urlForPath:[self pathForResource:@"files" trailing:path]];
}

- (NSString *)apiBaseURL {
    return [self urlForPath:@""];
}

#pragma mark - Properties

- (void)setAuthorityName:(NSString *)authorityName {
    // NOTE that slashes / in the name are replaced with dots; this is to ensure that
    // the authority name can take the place of a host name in a content: URL.
    _authorityName = [authorityName stringByReplacingOccurrencesOfString:@"/" withString:@"."];
}

#pragma mark - Private methods

// http://{host}/{apiroot}/{apiver}/path
- (NSString *)pathForResource:(NSString *)resourceName trailing:(NSString *)trailing {
    NSString *path = _pathRoot;
    path = [path stringByAppendingPathComponent:resourceName];
    path = [path stringByAppendingPathComponent:_account];
    path = [path stringByAppendingPathComponent:_repo];
    if (_branch) {
        path = [path stringByAppendingPathComponent:[@"~" stringByAppendingString:_branch]];
    }
    if (trailing) {
        path = [path stringByAppendingPathComponent:trailing];
    }
    return path;
}

- (NSString *)urlForPath:(NSString *)path {
    NSString *port = _port == 0 ? @"" : [NSString stringWithFormat:@":%ld", (long)_port];
    return [NSString stringWithFormat:@"%@://%@%@/%@", _protocol, _host, port, path];
}

@end
