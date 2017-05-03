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
#import "LOCMSFileset.h"
#import "LOCMSFilesetCategoryPathRoot.h"
#import "LOContentProvider.h"

@interface LOCMSRepository()

/// Force a content refresh.
- (QPromise *)forceRefresh;

@end

@implementation LOCMSRepository

- (id)init {
    self = [super init];
    if (self) {
        _fileDB = [[LOCMSFileDB alloc] initWithRepositry:self];
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
            /*
            @"posts": @{
                @"columns": @{
                    @"id":          @{ @"type": @"INTEGER", @"tag": @"id" },
                    @"type":        @{ @"type": @"STRING" },
                    @"title":       @{ @"type": @"STRING" },
                    @"body":        @{ @"type": @"STRING" },
                    @"image":       @{ @"type": @"INTEGER" },
                    @"commit":      @{ @"type": @"STRING",  @"tag": @"version" }

                }
            },
            */
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
//            @"post":    [SCDBORMMapping mappingWithRelation:@"object" table:@"posts"],
            @"commit":  [SCDBORMMapping mappingWithRelation:@"shared-object" table:@"commits"] //,
//            @"meta":    [SCDBORMMapping mappingWithRelation:@"map" table:@"meta"]
        }];
/*
        _fileDB.filesets = @{
            @"posts":       [LOCMSFileset filesetWithCache:@"none" mappings:@[ @"commit", @"meta", @"post" ]],
            @"pages":       [LOCMSFileset filesetWithCache:@"none" mappings:@[ @"commit", @"meta" ]],
            @"images":      [LOCMSFileset filesetWithCache:@"content" mappings:@[ @"commit", @"meta" ]],
            @"assets":      [LOCMSFileset filesetWithCache:@"content" mappings:@[ @"commit" ]],
            @"templates":   [LOCMSFileset filesetWithCache:@"app" mappings:@[ @"commit" ]]
        };
*/
/*
        self.pathRoots = [[LOJSONObject alloc] initWithDictionary:@{
            @"~posts":                  @"$postsPathRoot",
            @"~pages":                  @"$postsPathRoot",
            @"~files": @{
                @"@class":              @"LOCMSFilesetCategoryPathRoot"
            }
        }];
        self.refreshInterval = 1.0f; // Refresh once per minute.
*/
/*
    // Ensure a path root exists for each fileset, and is associated with the fileset.
    NSDictionary *filesets = fileDB.filesets;
    for (NSString *category in [filesets keyEnumerator]) {
        LOCMSFileset *fileset = filesets[category];
        // Note that fileset category path roots are prefixed with a tilde.
        NSString *pathRootName = [@"~" stringByAppendingString:category];
        id pathRoot = self.pathRoots[pathRootName];
        if (pathRoot == nil) {
            // Create a default path root for the current category.
            pathRoot = [[LOCMSFilesetCategoryPathRoot alloc] initWithFileset:fileset authority:authority];
            authority.pathRoots[pathRootName] = pathRoot;
        }
        else if ([pathRoot isKindOfClass:[LOCMSFilesetCategoryPathRoot class]]) {
            // Path root for category found, match it up with its fileset and the authority.
            ((LOCMSFilesetCategoryPathRoot *)pathRoot).fileset = fileset;
            ((LOCMSFilesetCategoryPathRoot *)pathRoot).authority = authority;
        }
    }
*/
        // TODO Record types (posts/pages): dbjson, html, webview
        // TODO Query types: dbjson, tableview
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

- (void)refreshContent {
    NSString *cmd = [NSString stringWithFormat:@"%@.refresh", self.authorityName];
    [self.provider.commandQueue queueCommandWithName:cmd arguments:@[]];
}

#pragma mark - LOAbstractContentAuthority overrides

- (BOOL)hasContentForPath:(LOContentPath *)path parameters:(NSDictionary *)parameters {
    NSString *filePath = [path relativePath];
    NSArray *result = [_fileDB performQuery:@"SELECT id FROM files WHERE path=?" withParams:@[ filePath ]];
    return [result count];
}

- (NSString *)localCacheLocationOfPath:(LOContentPath *)path paremeters:(NSDictionary *)parameters {
    NSString *cacheLocation = nil;
    NSString *filePath = [path relativePath];
    NSArray *result = [_fileDB performQuery:@"SELECT category FROM files WHERE path=?" withParams:@[ filePath ]];
    if ([result count] > 0) {
        NSDictionary *row = result[0];
        NSString *category = row[@"category"];
        LOCMSFileset *fileset = self.filesets[category];
        cacheLocation = [fileset cachePath:self];
    }
    return cacheLocation;
}

- (void)writeResponse:(id<LOContentAuthorityResponse>)response
              forPath:(LOContentPath *)path
           parameters:(NSDictionary *)parameters {
    
    // A tilde at the start of a path indicates a fileset category reference; so any path which
    // doesn't start with tilde is a direct reference to a file by its path. Convert the reference
    // to a fileset reference by looking up the file ID and category for the path.
    NSString *root = [path head];
    if (![root hasPrefix:@"~"]) {
        // Lookup file entry by path.
        NSString *filePath = [path fullPath];
        NSArray *result = [_fileDB performQuery:@"SELECT id, category FROM files WHERE path=?"
                                     withParams:@[ filePath ]];
        if ([result count] > 0) {
            // File entry found in database; rewrite content path to a direct resource reference.
            NSDictionary *row = result[0];
            NSString *fileID = row[@"id"];
            NSString *category = row[@"category"];
            NSString *resourcePath = [NSString stringWithFormat:@"~%@/$%@", category, fileID];
            NSString *ext = [path ext];
            if (ext) {
                resourcePath = [resourcePath stringByAppendingPathExtension:ext];
            }
            path = [[LOContentPath alloc] initWithPath:resourcePath];
        }
    }
    // Continue with standard response behaviour.
    [super writeResponse:response forPath:path parameters:parameters];
}

#pragma mark - Private

- (QPromise *)forceRefresh {
    // Refresh content.
    NSString *cmd = [NSString stringWithFormat:@"%@.refresh", self.authorityName];
    return [self.provider.commandQueue clearPendingAndExecuteCommandWithName:cmd arguments:@[]];
}

#pragma mark - SCIOCObjectAware

- (void)notifyIOCObject:(id)object propertyName:(NSString *)propertyName {
    // When the repo is configured as an authority within a content provider, use the name
    // is is mapped under as the authority name.
    self.cms.authorityName = propertyName;
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
    
    // Set file DB name and initial copy path.
    if (!_fileDB.name) {
        _fileDB.name = [NSString stringWithFormat:@"%@.%@", _cms.account, _cms.repo ];
    }
    if (!_fileDB.initialCopyPath) {
        NSString *filename = [_fileDB.name stringByAppendingPathExtension:@"sqlite"];
        _fileDB.initialCopyPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
    }

    _authManager = [[LOCMSAuthenticationManager alloc] initWithCMSSettings:_cms];
    _httpClient = [[SCHTTPClient alloc] initWithNSURLSessionTaskDelegate:(id<NSURLSessionTaskDelegate>)_authManager];
    _commandProtocol = [[LOCMSCommandProtocol alloc] initWithRepository:self];
    // Register command protocol with the scheduler, using the authority name as the command prefix.
    [_commandProtocol registerWithCommandQueue:self.provider.commandQueue];
    // Refresh the app content on start.
    [self refreshContent];
}

@end
