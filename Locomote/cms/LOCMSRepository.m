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
#import "LOContentProvider.h"
#import "LOCMSRepoRequestHandler.h"

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
        _fileDB.version = @2;
        _fileDB.tables = @{
            @"files": @{
                @"columns": @{
                    @"id":          @{ @"type": @"STRING", @"tag": @"id" },
                    @"path":        @{ @"type": @"STRING" },
                    @"category":    @{ @"type": @"STRING" },
                    @"status":      @{ @"type": @"STRING" },
                    @"version":     @{ @"type": @"STRING", @"tag": @"version" }
                }
            },
            @"pages": @{
                @"columns": @{
                    @"id":          @{ @"type": @"STRING", @"tag": @"id" },
                    @"type":        @{ @"type": @"STRING" },
                    @"title":       @{ @"type": @"STRING" },
                    @"content":     @{ @"type": @"STRING" },
                    @"image":       @{ @"type": @"STRING" },
                    @"version":     @{ @"type": @"STRING", @"tag": @"version" }

                }
            },
            @"commits": @{
                @"columns": @{
                    @"id":          @{ @"type": @"STRING", @"tag": @"id" },
                    @"date":        @{ @"type": @"STRING" },
                    @"subject":     @{ @"type": @"STRING" }
                }
            },
            @"fingerprints": @{
                @"columns": @{
                    @"category":    @{ @"type": @"STRING", @"tag": @"id" },
                    @"fingerprint": @{ @"type": @"STRING" },
                    @"preprint":    @{ @"type": @"STRING" },
                    @"current":     @{ @"type": @"STRING" },
                    @"latest":      @{ @"type": @"STRING" }
                }
            },
            @"meta": @{
                @"columns": @{
                    @"id":          @{ @"type": @"STRING", @"tag": @"id", @"format": @"{fileid}:{key}" },
                    @"fileid":      @{ @"type": @"STRING", @"tag": @"ownerid" },
                    @"key":         @{ @"type": @"STRING", @"tag": @"key" },
                    @"value":       @{ @"type": @"STRING" },
                    @"version":     @{ @"type": @"STRING", @"tag": @"version" }

                }
            }
        };
    
        _fileDB.orm = [SCDBORM ormWithSource:@"files" mappings:@{
            @"page":    [SCDBORMMapping mappingWithRelation:@"object"        table:@"pages"],
            @"commit":  [SCDBORMMapping mappingWithRelation:@"shared-object" table:@"commits"],
            @"meta":    [SCDBORMMapping mappingWithRelation:@"map"           table:@"meta"]
        }];
        
        _fileDB.filesets = @{
            @"pages":       [LOCMSFileset filesetWithCache:@"none"    mappings:@[ @"commit", @"meta", @"page" ]],
            @"images":      [LOCMSFileset filesetWithCache:@"content" mappings:@[ @"commit", @"meta" ]],
            @"assets":      [LOCMSFileset filesetWithCache:@"content" mappings:@[ @"commit" ]],
            @"templates":   [LOCMSFileset filesetWithCache:@"app"     mappings:@[ @"commit" ]]
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
    return [_fileDB cacheLocationForFileWithPath:path];
}

- (void)start {
    // Set file DB name and initial copy path.
    if (!_fileDB.name) {
        NSString *authorityName = self.authority.authorityName;
        _fileDB.name = [NSString stringWithFormat:@"%@/%@/filedb", authorityName, self.basePath];
    }
    if (!_fileDB.initialCopyPath) {
        NSString *filename = [_fileDB.name stringByAppendingPathExtension:@"sqlite"];
        _fileDB.initialCopyPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
    }
    _authManager = [[LOCMSAuthenticationManager alloc] initWithCMSSettings:_cms];
    _httpClient = [[SCHTTPClient alloc] initWithNSURLSessionTaskDelegate:(id<NSURLSessionTaskDelegate>)_authManager];
    /* TODO
    _httpClient.additionalHTTPHeaders = @{
        @"User-Agent": [self buildHTTPUserAgent]
    }
    */
    _commandProtocol = [[LOCMSCommandProtocol alloc] initWithRepository:self];
    // Register command protocol with the scheduler, using the authority name as the command prefix.
    [_commandProtocol registerWithCommandQueue:self.authority.commandQueue];
    // Check for an interrupted file db reset.
    [self continueDBResetInProgress];
}

- (QPromise *)syncContent {
    NSString *cmd = [NSString stringWithFormat:@"%@.refresh", self.basePath];
    return [self.authority.commandQueue queueCommandWithName:cmd arguments:@[]];
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
        [self.authManager removeCredentials];
        return YES;
    }
    return NO;
}


#pragma mark - Private

- (void)continueDBResetInProgress {
    // TODO Modify command queue api to accept authority name - it can then do the following line.
    NSString *command = [NSString stringWithFormat:@"%@.%@", self.authority.authorityName, @"reset-fileset"];
    LOCommandQueue *commandQueue = self.authority.commandQueue;
    // Query the file DB for any outstanding fileset resets, and reissue a reset command for each one.
    NSArray *fsresets = [_fileDB getInProgressResetRecords];
    for (NSDictionary *reset in fsresets) {
        NSString *category = reset[@"category"];
        id cacheLocation = [_fileDB cacheLocationForFileset:category];
        [commandQueue queueCommandWithName:command arguments:@[ category, cacheLocation, reset[@"cvs"] ]];
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
