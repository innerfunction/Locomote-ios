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
#define DefaultAPIProtocol  (@"http")
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
    self = [self init];
    if (self) {
        NSURL *baseURL = [NSURL URLWithString:[self urlForPath:@"/"]];
        NSURL *repoURL = [NSURL URLWithString:ref relativeToURL:baseURL];
        self.protocol = repoURL.scheme;
        if (repoURL.user) {
            self.username = repoURL.user;
        }
        if (repoURL.password) {
            self.password = repoURL.password;
        }
        self.host = repoURL.host;
        self.port = [repoURL.port integerValue];
        if ([repoURL.pathComponents count] > 2) {
            self.account = repoURL.pathComponents[1];
            self.repo = repoURL.pathComponents[2];
            if ([repoURL.pathComponents count] > 3) {
                self.branch = repoURL.pathComponents[3];
            }
        }
    }
    return self;
}

- (id)initAccount:(NSString *)account repository:(NSString *)repo {
    self = [self init];
    self.account = account;
    self.repo = repo;
    return self;
}

- (id)initWithAccount:(NSString *)account repository:(NSString *)repo username:(NSString *)username password:(NSString *)password {
    self = [self init];
    self.account = account;
    self.repo = repo;
    self.username = username;
    self.password = password;
    return self;
}

- (id)initWithHost:(NSString *)host account:(NSString *)account repository:(NSString *)repo {
    self = [self init];
    self.host = host;
    self.account = account;
    self.repo = repo;
    return self;
}

- (id)initWithHost:(NSString *)host account:(NSString *)account repository:(NSString *)repo username:(NSString *)username password:(NSString *)password {
    self = [self init];
    self.host = host;
    self.account = account;
    self.repo = repo;
    self.username = username;
    self.password = password;
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
