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

#import "LOCMSCommandProtocol.h"
#import "LOCMSFileset.h"
#import "LOCMSRepository.h"
#import "LOContentProvider.h"
#import "SCFileIO.h"

#define URLEncode(s)        ([s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]])
#define IsSecure            ([_protocol.authManager hasCredentials] ? @"true" : @"false")
#define AcceptMIMETypes     (@"application/msgpack, application/json;q=0.9, */*;q=0.8")
#define AcceptEncodings     (@"gzip")

#define QualifiedCommandName(protocol, name)    ([NSString stringWithFormat:@"%@.%@", protocol.commandPrefix, name ])

@interface LOCMSCommandProtocolRefresh : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
    QPromise *_promise;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

@end

@interface LOCMSCommandProtocolDownloadFileset : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
    QPromise *_promise;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

@end

@implementation LOCMSCommandProtocol

- (id)initWithRepository:(LOCMSRepository *)repository {
    self = [super init];
    self.cms = repository.cms;
    self.authManager = repository.authManager;
    // Use a copy of the file DB to avoid problems with multi-thread access.
    self.fileDB = [repository.fileDB newInstance];
    self.httpClient = repository.httpClient;
    self.commandPrefix = repository.authorityName;
    return self;
}

- (void)registerWithCommandQueue:(LOCommandQueue *)commandQueue {
    // TODO: Can't the command queue read the command name from the command??
    LOCMSCommandProtocolRefresh *refresh = [[LOCMSCommandProtocolRefresh alloc] initWithCommandProtocol:self];
    [commandQueue registerCommand:refresh];
    LOCMSCommandProtocolDownloadFileset *downloadFileset = [LOCMSCommandProtocolDownloadFileset new];
    [commandQueue registerCommand:downloadFileset];
}

@end

@implementation LOCMSCommandProtocolRefresh

@synthesize name=_name;

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol {
    self = [super init];
    if (self) {
        _name = QualifiedCommandName(protocol, @"refresh");
        _protocol = protocol;
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {
    
    _promise = [QPromise new];
    
    NSString *refreshURL = [_protocol.cms urlForUpdates];
    
    // Query the file DB for the latest commit ID.
    NSString *commit = nil, *group = nil;
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"secure"] = IsSecure;
    
    // Read current group fingerprint.
    NSDictionary *record = [_protocol.fileDB readRecordWithID:@"$group" fromTable:@"fingerprints"];
    if (record) {
        group = record[@"current"];
        params[@"group"] = group;
    }
    
    // Read latest commit ID.
    NSArray *rs = [_protocol.fileDB performQuery:@"SELECT id, max(date) FROM commits" withParams:@[]];
    if ([rs count] > 0) {
        // File DB contains previous commits, read latest commit ID and add as request parameter.
        NSDictionary *record = rs[0];
        commit = [record[@"id"] description];
        params[@"since"] = commit;
    }
    // Otherwise simply omit the 'since' parameter; the feed will return all records in the file DB.

    // Specify accepts options.
    NSDictionary *options = @{
        SCHTTPClientRequestOptionAccept:            AcceptMIMETypes,
        SCHTTPClientRequestOptionAcceptEncoding:    AcceptEncodings
    };
    // Fetch updates from the server.
    [_protocol.httpClient get:refreshURL data:params options:options]
    .then((id)^(SCHTTPClientResponse *response) {
    
        LOCMSAuthenticationManager *authManager = _protocol.authManager;
        LOCMSFileDB *fileDB = _protocol.fileDB;
        
        // Create list of follow up commands.
        NSMutableArray *commands = [NSMutableArray new];
        NSInteger responseCode = response.httpResponse.statusCode;
        if (responseCode == 401) {
            [authManager removeCredentials];
            [_promise resolve:commands];
            return nil;
        }
        
        // Read the updates data.
        id updateData = [response parseData];
        if ([updateData isKindOfClass:[NSString class]]) {
            // Indicates a server error
            NSLog(@"%@ %@", response.httpResponse.URL, updateData);
            [_promise resolve:commands];
            return nil;
        }

        /*
        // Check file DB schema version.
        id version = [updateData valueForKeyPath:@"db.version"];
        if (![version isEqual:_fileDB.version]) {
            // Update the file DB schema and then schedule a new refresh.
            id updateSchema = @{
                @"name": [self qualifyName:@"update-schema"],
                @"args": @[ version ]
            };
            id refresh = @{
                @"name": [self qualifyName:@"refresh"],
                @"args": @[]
            };
            [commands addObject:updateSchema];
            [commands addObject:refresh];
            NSLog(@"Database version mismatch error");
        }
        else {
        */
            // Write updates to database.
            NSDictionary *updates = [updateData valueForKeyPath:@"db"];
            if ([@0 isEqual:updates]) {
                // This can happen no updates to report from the server; replace updates
                // with an empty dictionary.
                updates = @{};
            }
            // A map of fileset category names to a 'since' commit value (may be null).
            NSMutableDictionary *updatedCategories = [NSMutableDictionary new];
        
            // Start a DB transaction.
            [fileDB beginTransaction];
        
        
            // Check group fingerprint to see if a migration is needed.
            NSString *updateGroup = [updateData valueForKeyPath:@"repository.group"];
            BOOL migrate = ![group isEqualToString:updateGroup];
            if (migrate) {
                // Performing a migration due to an ACM group ID change; mark all files as
                // provisionaly deleted.
                [fileDB performUpdate:@"UPDATE files SET status='deleted'" withParams:@[]];
            }
        
            // TODO filesets : previous / current / latest - need to work out details of operation.
            // For example, following statement may not be needed if using current + latest to
            // track downloaded version of filesets.
            // But also note previous / current are fingerprints i.e. fileset definition fingerprints;
            // whilst current / latest are commits.
            // So now: fingerprint, preprint (previous fingerprint), current, latest
            // Following statement becomes UPDATE filesets SET preprint=fingerprint
            // As fileset categories are updated, the fileset's latest is updated to the current commit
            // At end, issue fileset download for SELECT category FROM fileset WHERE latest != current OR fingerprint != preprint
        
            // Shift current fileset fingerprints to previous.
            [fileDB performUpdate:@"UPDATE filesets SET previous=current" withParams:@[]];

            // Apply all downloaded updates to the database.
            for (NSString *tableName in updates) {
                BOOL isFilesTable = [@"files" isEqualToString:tableName];
                NSArray *table = updates[tableName];
                for (NSDictionary *values in table) {
                    [fileDB upsertValues:values intoTable:tableName];
                    // If processing the files table then record the updated file category name.
                    if (isFilesTable) {
                        NSString *category = values[@"category"];
                        NSString *status = values[@"status"];
                        if (category != nil && ![@"deleted" isEqualToString:status]) {
                            if (commit) {
                                updatedCategories[category] = commit;
                            }
                            else {
                                updatedCategories[category] = [NSNull null];
                            }
                        }
                    }
                }
            }
        
            // Check for deleted files.
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSArray *deleted = [fileDB performQuery:@"SELECT id, path FROM files WHERE status='deleted'" withParams:@[]];
            for (NSDictionary *record in deleted) {
                // Delete cached file, if exists.
                NSString *path = [fileDB cacheLocationForFile:record];
                if (path && [fileManager fileExistsAtPath:path]) {
                    [fileManager removeItemAtPath:path error:nil];
                }
            }
        
            // Delete obsolete records.
            [fileDB performUpdate:@"DELETE FROM files WHERE status='deleted'" withParams:@[]];

            // Prune ORM related records.
            [fileDB pruneRelatedValues];
        
            // Read list of fileset names with modified fingerprints.
            NSArray *rows = [fileDB performQuery:@"SELECT category FROM fingerprints WHERE current != previous" withParams:@[]];
            for (NSDictionary *row in rows) {
                NSString *category = row[@"category"];
                if ([@"$group" isEqualToString:category]) {
                    // The ACM group fingerprint entry - skip.
                    continue;
                }
                // Map the category name to null - this indicates that the category is updated,
                // but there is no 'since' parameter, so download a full update.
                updatedCategories[category] = [NSNull null];
            }
        
            // Queue downloads of updated category filesets.
            NSString *command = QualifiedCommandName(_protocol, @"download-fileset");
            for (id category in [updatedCategories keyEnumerator]) {
                id since = updatedCategories[category];
                // Get cache location for fileset; if nil then don't download the fileset.
                NSString *cacheLocation = [fileDB cacheLocationForFileset:category];
                if (cacheLocation) {
                    NSMutableArray *args = [NSMutableArray new];
                    [args addObject:category];
                    [args addObject:cacheLocation]; // Where to put the downloaded files.
                    if (since != [NSNull null]) {
                        [args addObject:since];
                    }
                    [commands addObject:@{ @"name": command, @"args": args }];
                }
            }

            // Commit the transaction.
            [fileDB commitTransaction];
            
            // QUESTIONS ABOUT THE CODE ABOVE
            // 1. How does the code perform if the procedure above is interrupted before completion?
            // 2. How is app performance affected if the procedure above is continually interrupted?
            //    (e.g. due to repeated short-duration app starts).
            // 3. Are there ways (on iOS and Android) to run tasks like this with completion guarantees?
            //    e.g. the scheduler could register as a background task when app is put into the background;
            //    the task compeletes when the currently executing command completes.
            //    See https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/BackgroundExecution/BackgroundExecution.html
            
        /* -- end of else after db version check
        }
        */
        [_promise resolve:commands];
        return nil;
    })
    .fail(^(id error) {
        NSString *msg = [NSString stringWithFormat:@"Updates download from %@ failed: %@", refreshURL, error];
        [_promise reject:msg];
    });
    
    // Return deferred promise.
    return _promise;
}

@end

@implementation LOCMSCommandProtocolDownloadFileset

@synthesize name=_name;

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol {
    self = [super init];
    if (self) {
        _name = QualifiedCommandName(protocol, @"download-fileset");
        _protocol = protocol;
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {
    
    _promise = [QPromise new];
    
    id category = args[0];
    id cachePath = args[1];
    
    // Build the fileset URL and query parameters.
    NSString *filesetURL = [_protocol.cms urlForFileset:category];
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"secure"] = IsSecure;
    if ([args count] > 2) {
        data[@"since"] = args[2];
    }
    
    // Download the fileset.
    [_protocol.httpClient getFile:filesetURL data:data]
    .then((id)^(SCHTTPClientResponse *response) {
        NSInteger responseCode = response.httpResponse.statusCode;
        if (responseCode == 200) {
            // Unzip downloaded file to content location.
            NSString *downloadPath = [response.downloadLocation path];
            [SCFileIO unzipFileAtPath:downloadPath toPath:cachePath overwrite:YES];
        }
        if (responseCode == 200 || responseCode == 204) {
            // Update the fileset's fingerprint.
            [_protocol.fileDB performUpdate:@"UPDATE filesets SET current=latest WHERE category=?" withParams:@[ category ]];
        }
        // Resolve empty list - no follow-on commands.
        [_promise resolve:@[]];
        return nil;
    })
    .fail(^(id error) {
        NSString *msg = [NSString stringWithFormat:@"Fileset download from %@ failed: %@", filesetURL, error];
        [_promise reject:msg];
    });

    // Return deferred promise.
    return _promise;
}

@end
