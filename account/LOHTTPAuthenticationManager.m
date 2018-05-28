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
//  Created by Julian Goacher on 30/11/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOHTTPAuthenticationManager.h"
#import "SSKeychain.h"

@interface LOHTTPAuthenticationManager()

- (NSURLCredential *)getCredentialForUsername:(NSString *)username;
- (NSString *)getActiveUsername;
- (void)unsetActiveUser;
- (NSString *)getUserDefaultsKey:(NSString *)keyName;

@end

@implementation LOHTTPAuthenticationManager

- (id)initWithHost:(NSString *)host port:(NSInteger)port protocol:(NSString *)protocol realm:(NSString *)realm {
    self = [super init];
    if (self) {
        _protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:host
                                                                 port:port
                                                             protocol:protocol
                                                                realm:realm
                                                 authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
        
        // Startup check - make sure the active user matches the default credential.
        // (Credentials might be removed; or the logout process might be interrupted).
        NSString *username = [self getActiveUsername];
        if (username) {
            NSURLCredential *credential = [self getCredentialForUsername:username];
            if (!credential) {
                // No credential found for user, so unset the active user.
                [self unsetActiveUser];
            }
            else {
                // Reset the default credential to ensure it matches the active user.
                NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
                [storage setDefaultCredential:credential forProtectionSpace:_protectionSpace];
            }
        }
    }
    return self;
}

- (void)registerCredentials:(NSDictionary *)credentials {
    NSString *username = credentials[LOUserProfileUsername];
    NSString *password = credentials[LOUserProfilePassword];
    [self registerUsername:username password:password];
}

- (void)registerUsername:(NSString *)username password:(NSString *)password {
    if (username && password) {
        NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
        // Check for an existing credential with the same username.
        NSURLCredential *credential = [self getCredentialForUsername:username];
        if (credential) {
            // Existing credential found, delete it before continuing.
            [storage removeCredential:credential forProtectionSpace:_protectionSpace];
        }
        // Create the credential.
        credential = [NSURLCredential credentialWithUser:username
                                                password:password
                                             persistence:NSURLCredentialPersistencePermanent];
        // Set the default credential.
        [storage setDefaultCredential:credential forProtectionSpace:_protectionSpace];
        // Record that we have credentials
        NSString *key = [self getUserDefaultsKey:@"activeUsername"];
        [[NSUserDefaults standardUserDefaults] setObject:username forKey:key];
    }
}

- (BOOL)hasCredentials {
    // Check if there is a currently active user.
    return [self getActiveUsername] != nil;
}

- (void)removeCredentials {
    NSURLCredential *credential = nil;
    NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
    // Check for an active user.
    NSString *username = [self getActiveUsername];
    if (username != nil) {
        // Find the active user's credentials.
        credential = [self getCredentialForUsername:username];
    }
    if (credential) {
        // Remove the active user's credentials.
        [storage removeCredential:credential forProtectionSpace:_protectionSpace];
    }
    // Reset the default credentials to empty username + password.
    credential = [self getCredentialForUsername:@""];
    if (!credential) {
        credential = [NSURLCredential credentialWithUser:@""
                                                password:@""
                                             persistence:NSURLCredentialPersistencePermanent];
    }
    [storage setDefaultCredential:credential forProtectionSpace:_protectionSpace];
    // Unset the active user.
    if (username) {
        [self unsetActiveUser];
    }
}

- (NSURLCredential *)getCredentialForUsername:(NSString *)username {
    NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
    NSDictionary *credentials = [storage credentialsForProtectionSpace:_protectionSpace];
    return credentials[username];
}

- (NSString *)getActiveUsername {
    NSString *key = [self getUserDefaultsKey:@"activeUsername"];
    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return username;
}

- (void)unsetActiveUser {
    NSString *key = [self getUserDefaultsKey:@"activeUsername"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

- (NSString *)getUserDefaultsKey:(NSString *)keyName {
    // Return a user defaults key by concatenating the following:
    // 1. The class name;
    // 2. The 16 digit hex encoded hash of a description of the associated protection space;
    // 3. The named key.
    NSString *prefix = [[self class] description];
    NSString *pspace = [NSString stringWithFormat:@"%@:%@:%@:%ld/%@",
                            [[self class] description],
                            _protectionSpace.protocol,
                            _protectionSpace.host,
                            (long)_protectionSpace.port,
                            _protectionSpace.realm];
    return [NSString stringWithFormat:@"%@.%016lX.%@", prefix, (unsigned long)[pspace hash], keyName];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {

    if (challenge.previousFailureCount == 0) {
        NSString *username = [self getActiveUsername];
        if (username) {
            NSURLCredential *credential = [self getCredentialForUsername:username];
            if (credential) {
                completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                return;
            }
        }
    }
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}


@end
