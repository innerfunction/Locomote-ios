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

#define DefaultAPIProtocol  (@"https")
#define DefaultAPIHost      (@"locomote.sh")
#define DefaultAPIVersion   (@"0.2")
#define DefaultAPIRoot      (@"cms")
#define AuthRealmPrefix     (@"sh.locomote")
#define DefaultBaseURL      ([NSString stringWithFormat:@"%@://%@/%@/%@", DefaultAPIProtocol, DefaultAPIHost, DefaultAPIRoot, DefaultAPIVersion])

@interface LOCMSSettings()

- (NSString *)pathForResource:(NSString *)resourceName trailing:(NSString *)trailing;
- (NSString *)urlForPath:(NSString *)path;
+ (NSDictionary *)parseURLParameters:(NSURL *)url;

@end

@implementation LOCMSSettings

- (id)init {
    self = [super init];
    self.protocol = DefaultAPIProtocol;
    self.host     = DefaultAPIHost;
    self.port     = 0;
    self.basePath = [DefaultAPIRoot stringByAppendingPathComponent:DefaultAPIVersion];
    return self;
}

- (id)initWithRef:(NSString *)ref {

    self = [super init];
    
    // Ref is a whole or partial, absolute or relative URL which is resolved against
    // the default repository base URL as defined in this class (e.g. https://locomote.sh/cms/0.2/).
    NSURL *baseURL = [NSURL URLWithString:DefaultBaseURL];
    NSURL *repoURL = [NSURL URLWithString:ref relativeToURL:baseURL];
    
    self.protocol = repoURL.scheme;
    self.host     = repoURL.host;
    if (repoURL.port) {
        self.port = [repoURL.port integerValue];
    }
    self.basePath = repoURL.path;
    self.username = repoURL.user;
    self.password = repoURL.password;
    
    // Allow the URL fragment to override the default authority name.
    if (repoURL.fragment) {
        self.authorityName = repoURL.fragment;
    }

    return self;
}

- (NSString *)authRealm {
    if (!_authRealm) {
        _authRealm = [NSString stringWithFormat:@"%@/%@", AuthRealmPrefix, _basePath];
    }
    return _authRealm;
}

- (NSString *)urlForAuthentication {
    return [self urlForPath:[self pathForResource:@"authenticate.api" trailing:nil]];
}

- (NSString *)urlForUpdates {
    return [self urlForPath:[self pathForResource:@"updates.api" trailing:nil]];
}

- (NSString *)urlForFileset:(NSString *)category {
    return [self urlForPath:[self pathForResource:@"filesets.api" trailing:category]];
}

- (NSString *)urlForFile:(NSString *)path {
    return [self urlForPath:[self pathForResource:@"files.api" trailing:path]];
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

- (void)setBasePath:(NSString *)basePath {
    // Ensure that the path has a trailing slash.
    if (![basePath hasSuffix:@"/"]) {
        basePath = [basePath stringByAppendingString:@"/"];
    }
    // Assign to the property.
    _basePath = basePath;
}

#pragma mark - Private methods

// http://{host}/{apiroot}/{apiver}/path
- (NSString *)pathForResource:(NSString *)resourceName trailing:(NSString *)trailing {
    NSString *path = [_basePath stringByAppendingPathComponent:resourceName];
    if (trailing) {
        path = [path stringByAppendingPathComponent:trailing];
    }
    return path;
}

- (NSString *)urlForPath:(NSString *)path {
    NSString *port = _port == 0 ? @"" : [NSString stringWithFormat:@":%ld", (long)_port];
    return [NSString stringWithFormat:@"%@://%@%@/%@", _protocol, _host, port, path];
}

#pragma mark - Class members

+ (NSDictionary *)parseURLParameters:(NSURL *)url {
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    NSArray *kvPairs = [url.query componentsSeparatedByString:@"&"];
    for (NSString *kvPair in kvPairs) {
        NSArray *kv     = [kvPair componentsSeparatedByString:@"="];
        NSString *key   = [kv[0] stringByRemovingPercentEncoding];
        NSString *value = [kv[1] stringByRemovingPercentEncoding];
        parameters[key] = value;
    }
    return parameters;
}

@end
