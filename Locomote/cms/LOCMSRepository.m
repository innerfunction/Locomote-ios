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
#import "Locomote.h"
#import "LOCMSContentAuthority.h"
#import "LOCMSFileset.h"
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
        _fileDB.version = @1;
        _fileDB.tables = @{
            @"files": @{
                @"columns": @{
                    @"id":          @{ @"type": @"INTEGER", @"tag": @"id" },
                    @"path":        @{ @"type": @"STRING" },
                    @"category":    @{ @"type": @"STRING" },
                    @"status":      @{ @"type": @"STRING" },
                    @"commit":      @{ @"type": @"STRING",  @"tag": @"version" }
                }
            },
            @"pages": @{
                @"columns": @{
                    @"id":          @{ @"type": @"INTEGER", @"tag": @"id" },
                    @"type":        @{ @"type": @"STRING" },
                    @"title":       @{ @"type": @"STRING" },
                    @"content":     @{ @"type": @"STRING" },
                    @"image":       @{ @"type": @"INTEGER" },
                    @"commit":      @{ @"type": @"STRING",  @"tag": @"version" }

                }
            },
            @"commits": @{
                @"columns": @{
                    @"commit":      @{ @"type": @"STRING",  @"tag": @"id" },
                    @"date":        @{ @"type": @"STRING" },
                    @"subject":     @{ @"type": @"STRING" }
                }
            },
            @"filesets": @{
                @"columns": @{
                    @"category":    @{ @"type": @"STRING",  @"tag": @"id" },
                    @"fingerprint": @{ @"type": @"STRING" },
                    @"preprint":    @{ @"type": @"STRING" },
                    @"current":     @{ @"type": @"STRING" },
                    @"latest":      @{ @"type": @"STRING" }
                }
            },
            @"meta": @{
                @"columns": @{
                    @"id":          @{ @"type": @"STRING",  @"tag": @"id", @"format": @"{fileid}:{key}" },
                    @"fileid":      @{ @"type": @"INTEGER", @"tag": @"ownerid" },
                    @"key":         @{ @"type": @"STRING",  @"tag": @"key" },
                    @"value":       @{ @"type": @"STRING" },
                    @"commit":      @{ @"type": @"STRING",  @"tag": @"version" }

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

- (NSDictionary *)filesets {
    return _fileDB.filesets;
}

- (void)setBasePath:(NSString *)basePath {
    // Ensure that the path has a trailing slash.
    if (![basePath hasSuffix:@"/"]) {
        basePath = [basePath stringByAppendingString:@"/"];
    }
    // Assign to the property.
    _basePath = basePath;
}

- (void)setAuthority:(LOCMSContentAuthority *)authority {
    _authority = authority;
    // Derive settings from the authority's settings.
    _cms = [[LOCMSSettings alloc] initWithSettings:authority.settings.xxx];
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

#pragma mark - SCService

- (void)startService {

    // Extract account / repo / branch info from the path.
    NSArray *components = [_basePath componentsSeparatedByString:@"/"];
    switch ([_basePath length]) {
        case 3:
            _cms.branch  = components[2];
        case 2:
            _cms.repo    = components[1];
        case 1:
            _cms.account = components[0];
            break;
        default:
            // TODO: Should be an error?
            break;
    }

    // Set file DB name and initial copy path.
    if (!_fileDB.name) {
        NSString *authorityName = self.authority.authorityName;
        _fileDB.name = [NSString stringWithFormat:@"%@/%@/%@_%@", authorityName, self.cms.account, self.cms.repo, self.cms.branch];
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
    
    // Refresh the app content on start.
    [self refreshContent];
}

#pragma mark - Private

- (void)continueDBResetInProgress {
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

- (NSString *)buildHTTPUserAgent {
    NSString *dpi = [NSString stringWithFormat:@"@%.fx", [UIScreen mainScreen].scale];
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    return [NSString stringWithFormat:@"Locomote/%s %@ (dpi=%@,locale=%@)",
            Locomote_iosVersionString, SDKPlatform, dpi, locale.localeIdentifier];
}

@end
