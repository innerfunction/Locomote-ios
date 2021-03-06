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
//  Created by Julian Goacher on 13/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOCMSRepository.h"
#import "LOCMSContentAuthority.h"
#import "LOCMSFileset.h"
#import "LOCMSRepoRequestHandler.h"
#import "LOContentProvider.h"

#define SDKPlatform (@"ios")

@interface LOCMSRepository()

/**
 * Check if a file DB reset was in progress (and interrupted when the app was stopped); if so
 * then issue commands to continue the reset.
 */
- (void)continueDBResetInProgress;
/// Build the HTTP client user agent string.
- (NSString *)buildHTTPUserAgent;

@end

@implementation LOCMSRepository

- (id)init {
    self = [super init];
    if (self) {
        _fileDB = [[LOCMSFileDB alloc] initWithRepository:self];
        _fileDB.name = @"filedb";
        _fileDB.version = @2;
        _fileDB.tables = @{
            @"files": @{
                @"columns": @{
                    @"id":          @{ @"type": @"TEXT", @"tag": @"id" },
                    @"path":        @{ @"type": @"TEXT" },
                    @"category":    @{ @"type": @"TEXT" },
                    @"status":      @{ @"type": @"TEXT" },
                    @"version":     @{ @"type": @"TEXT", @"tag": @"version" }
                }
            },
            @"pages": @{
                @"columns": @{
                    @"id":          @{ @"type": @"TEXT", @"tag": @"id" },
                    @"type":        @{ @"type": @"TEXT" },
                    @"title":       @{ @"type": @"TEXT" },
                    @"sort":        @{ @"type": @"TEXT" },
                    @"content":     @{ @"type": @"TEXT" },
                    @"image":       @{ @"type": @"TEXT" },
                    @"version":     @{ @"type": @"TEXT", @"tag": @"version" }

                }
            },
            @"commits": @{
                @"columns": @{
                    @"id":          @{ @"type": @"TEXT", @"tag": @"id" },
                    @"date":        @{ @"type": @"TEXT" },
                    @"subject":     @{ @"type": @"TEXT" }
                }
            },
            @"fingerprints": @{
                @"columns": @{
                    @"category":    @{ @"type": @"TEXT", @"tag": @"id" },
                    @"fingerprint": @{ @"type": @"TEXT" },
                    @"preprint":    @{ @"type": @"TEXT" },
                    @"current":     @{ @"type": @"TEXT" },
                    @"latest":      @{ @"type": @"TEXT" }
                }
            },
            @"meta": @{
                @"columns": @{
                    @"id":          @{ @"type": @"TEXT", @"tag": @"id", @"format": @"{fileid}:{key}" },
                    @"fileid":      @{ @"type": @"TEXT", @"tag": @"ownerid" },
                    @"key":         @{ @"type": @"TEXT", @"tag": @"key" },
                    @"value":       @{ @"type": @"TEXT" },
                    @"version":     @{ @"type": @"TEXT", @"tag": @"version" }

                }
            }
        };
    
        _fileDB.orm = [SCDBORM ormWithSource:@"files" mappings:@{
            @"page":       [SCDBORMMapping mappingWithRelation:@"object"        table:@"pages"],
            @"version":    [SCDBORMMapping mappingWithRelation:@"shared-object" table:@"commits"],
            @"meta":       [SCDBORMMapping mappingWithRelation:@"map"           table:@"meta"]
        }];
        
        _fileDB.filesets = @{
            @"pages":       [LOCMSFileset filesetWithCategory:@"pages"
                                                        cache:@"none"
                                                     mappings:@[ @"version", @"meta", @"page" ]],
            @"images":      [LOCMSFileset filesetWithCategory:@"images"
                                                        cache:@"content"
                                                     mappings:@[ @"version", @"meta" ]],
            @"assets":      [LOCMSFileset filesetWithCategory:@"assets"
                                                        cache:@"content"
                                                     mappings:@[ @"version" ]],
            @"templates":   [LOCMSFileset filesetWithCategory:@"templates"
                                                        cache:@"app"
                                                     mappings:@[ @"version" ]]
        };
        
        self.requestHandler = [[LOCMSRepoRequestHandler alloc] initWithRepository:self];
    }
    return self;
}

- (id)initWithSettings:(LOCMSSettings *)settings {
    self = [self init];
    self.cms = settings;
    return self;
}

- (NSDictionary *)filesets {
    return _fileDB.filesets;
}

- (void)setCms:(LOCMSSettings *)cms {
    _cms = cms;
    self.basePath = cms.basePath;
}

- (void)setAuthority:(LOCMSContentAuthority *)authority {
    _authority = authority;
    self.localCachePaths = [[LOLocalCachePaths alloc] initWithSettings:authority.localCachePaths suffix:_basePath];
}

- (QPromise *)refreshContent {
    return [self syncContent];
}

- (BOOL)hasContentForPath:(NSString *)path parameters:(NSDictionary *)parameters {
    NSString *sql = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE path=?", _fileDB.filesTable ];
    NSArray *result = [_fileDB performQuery:sql withParams:@[ path ]];
    return [result count];
}

- (NSString *)localCacheLocationOfPath:(NSString *)path parameters:(NSDictionary *)parameters {
    return [_fileDB cacheLocationForFile:path];
}

- (void)completeSetup {
    LOHTTPAuthenticationManager *authManager = [[LOHTTPAuthenticationManager alloc] initWithHost:_cms.host
                                                                                            port:_cms.port
                                                                                        protocol:_cms.protocol
                                                                                           realm:_cms.authRealm];
    
    _httpClient = [[SCHTTPClient alloc] initWithNSURLSessionTaskDelegate:(id<NSURLSessionTaskDelegate>)authManager];
    
    // If a user account manager is present then pass it a reference to the auth manager.
    if (_accountManager) {
        _accountManager.authManager = authManager;
    }
    
    /* TODO
    _httpClient.additionalHTTPHeaders = @{
        @"User-Agent": [self buildHTTPUserAgent]
    }
    */
        // Init and register command protocol with the scheduler, using the authority name as the command prefix.
    _ops = [[LOCMSOperationProtocol alloc] initWithFileDB:_fileDB
                                                 settings:_cms
                                               httpClient:_httpClient
                                    authenticationManager:authManager];

}

- (void)start {
    // Set file DB name and initial copy path.
    if (!_fileDB.name) {
        NSString *authorityName = self.authority.authorityName;
        _fileDB.name = [NSString stringWithFormat:@"%@/%@/filedb", authorityName, self.basePath];
    }
    if (!_fileDB.initialCopyPath) {
        NSString *filename = [_fileDB.name stringByAppendingPathExtension:@"sqlite"];
        NSString *path = [[NSBundle mainBundle] resourcePath];
        path = [path stringByAppendingPathComponent:_authority.authorityName];
        path = [path stringByAppendingPathComponent:_basePath];
        path = [path stringByAppendingPathComponent:filename];
        _fileDB.initialCopyPath = path;
    }
    
    [_fileDB startService];

    [_ops startService];
    
    // Check for an interrupted file db reset.
    [self continueDBResetInProgress];
}

- (QPromise *)syncContent {
    return [_ops refresh];
}

#pragma mark - LORequestHandler

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {
    // Strip the base path from the start of the request path before forwarding to
    // the registered request handlers.
    request.path = [request.path substringFromIndex:[_basePath length]];
    [_requestHandler handleRequest:request response:response];
}

#pragma mark - SCIOCObjectAware

- (void)notifyIOCObject:(id)object propertyName:(NSString *)propertyName {
    // When the repo is configured as an authority within a content provider, use the name
    // is is mapped under as the base path.
    self.basePath = propertyName;
}

#pragma mark - SCMessageReceiver

- (BOOL)receiveMessage:(SCMessage *)message sender:(id)sender {
    if ([message.name isEqualToString:@"logout"]) {
        [self.accountManager logout];
        return YES;
    }
    return NO;
}


#pragma mark - Private

- (void)continueDBResetInProgress {
    // Query the file DB for any outstanding fileset resets, and reissue a reset command for each one.
    NSArray *fsresets = [_fileDB getInProgressResetRecords];
    for (NSDictionary *reset in fsresets) {
        NSString *category = reset[@"category"];
        id cacheLocation = [_fileDB cacheLocationForFileset:category];
        if (cacheLocation) {
            [_ops resetFileset:category];
        }
        // else unsupported fileset.
    }
}

#define Locomote_Version @"1.0"

- (NSString *)buildHTTPUserAgent {
    NSString *dpi = [NSString stringWithFormat:@"@%.fx", [UIScreen mainScreen].scale];
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    return [NSString stringWithFormat:@"Locomote/%@ %@ (dpi=%@,locale=%@)",
            Locomote_Version, SDKPlatform, dpi, locale.localeIdentifier];
}

@end
