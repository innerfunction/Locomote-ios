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
#import "LOCMSContentAuthority.h"
#import "LOContentProvider.h"
#import "SCFileIO.h"

#define URLEncode(s)        ([s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]])
#define IsSecure            ([_protocol.authManager hasCredentials] ? @"true" : @"false")
#define AcceptMIMETypes     (@"application/msgpack, application/json;q=0.9, */*;q=0.8")
#define AcceptEncodings     (@"gzip")

#define QualifiedCommandName(protocol, name)    ([NSString stringWithFormat:@"%@.%@", protocol.commandPrefix, name ])

/// Refresh the file DB by pulling updates from the server.
@interface LOCMSCommandProtocolRefresh : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
    QPromise *_promise;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

@end

/// Perform a file DB reset.
@interface LOCMSCommandProtocolResetDatabase : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
    QPromise *_promise;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

/**
 * Build a JSON document describing the client visible set for a fileset category.
 * If the category name is nil then the set returned is for the entire file database.
 * The client visible set describes what files are currently visible to the Locomote client.
 * The JSON document is an object with a "cvs" property whose value is an array of ( file ID,
 * file version ) tuples.
 * The CVS is used by the server during a file db reset to work out what file updates the
 * client needs to see.
 */
- (NSString *)buildClientVisibleSetForCategory:(NSString *)category;

@end

/// Download files in a fileset category.
@interface LOCMSCommandProtocolDownloadFileset : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
    QPromise *_promise;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

@end

/// Download files as part of a fileset reset.
@interface LOCMSCommandProtocolResetFileset : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
    QPromise *_promise;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

@end

/// Remove files marked as deleted in the file database.
@interface LOCMSCommandProtocolFileGC : NSObject <LOCommand> {
    __weak LOCMSCommandProtocol *_protocol;
}

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol;

@end

@interface LOCMSCommandProtocol ()

@end

@implementation LOCMSCommandProtocol

- (id)initWithRepository:(LOCMSRepository *)repository {
    self = [super init];
    self.cms = repository.cms;
    self.authManager = repository.authManager;
    // Use a copy of the file DB to avoid problems with multi-thread access.
    self.fileDB = [repository.fileDB newInstance];
    self.httpClient = repository.httpClient;
    self.commandPrefix = repository.authority.authorityName;
    return self;
}

- (void)registerWithCommandQueue:(LOCommandQueue *)commandQueue {
    LOCMSCommandProtocolRefresh *refresh = [[LOCMSCommandProtocolRefresh alloc] initWithCommandProtocol:self];
    [commandQueue registerCommand:refresh];
    LOCMSCommandProtocolResetDatabase *resetDatabase = [[LOCMSCommandProtocolResetDatabase alloc] initWithCommandProtocol:self];
    [commandQueue registerCommand:resetDatabase];
    LOCMSCommandProtocolDownloadFileset *downloadFileset = [[LOCMSCommandProtocolDownloadFileset alloc] initWithCommandProtocol:self];
    [commandQueue registerCommand:downloadFileset];
    LOCMSCommandProtocolResetFileset *resetFileset = [[LOCMSCommandProtocolResetFileset alloc] initWithCommandProtocol:self];
    [commandQueue registerCommand:resetFileset];
    LOCMSCommandProtocolFileGC *fileGC = [[LOCMSCommandProtocolFileGC alloc] initWithCommandProtocol:self];
    [commandQueue registerCommand:fileGC];
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
    
    NSString *refreshURL = _protocol.cms.updatesURL;
    
    // Query the file DB for the latest commit ID.
    NSString *commit = nil, *group = nil;
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"secure"] = IsSecure;
    
    // Read current ACM group fingerprint.
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
    
        LOCMSAuthenticationManager *authManager = self->_protocol.authManager;
        LOCMSFileDB *fileDB = self->_protocol.fileDB;
        
        // Check the response code.
        NSInteger responseCode = response.httpResponse.statusCode;
        if (responseCode == 401) {
            [authManager removeCredentials];
            [self->_promise resolve:@[]];
            return nil;
        }
        
        // LS-13: ACM group mismatch, perform a database reset.
        if (responseCode == 205) {
            NSString *command = QualifiedCommandName(self->_protocol, @"reset");
            [self->_promise resolve:@[ @{ @"name": command, @"args": @[] } ]];
            return nil;
        }
        
        // Read the updates data.
        id updateData = [response parseData];
        if ([updateData isKindOfClass:[NSString class]]) {
            // Indicates a server error
            NSLog(@"%@ %@", response.httpResponse.URL, updateData);
            [self->_promise resolve:@[]];
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

            // Prune ORM related records.
            [fileDB pruneRelatedValues];
        
            // A list of follow up commands.
            NSMutableArray *commands = [NSMutableArray new];

            // Queue command to delete unused files.
            [commands addObject:@{ @"name": QualifiedCommandName(self->_protocol, @"file-gc"), @"args": @[] }];

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
            NSString *command = QualifiedCommandName(self->_protocol, @"download-fileset");
            for (id category in [updatedCategories keyEnumerator]) {
                id since = updatedCategories[category];
                // Get cache location for fileset; if nil then don't download the fileset.
                NSString *cacheLocation = [fileDB cacheLocationForFileset:category];
                if (cacheLocation) {
                    NSMutableArray *args = [NSMutableArray new];
                    [args addObject:category];
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
            //    > DB changes won't be applied unless transaction is committed
            //    > Some deleted files may be deleted from the filesystem whilst record remains - this is ok.
            // 2. How is app performance affected if the procedure above is continually interrupted?
            //    (e.g. due to repeated short-duration app starts).
            //    > Updates never show. This is an edge case, unlikely to be a problem.
            // 3. Are there ways (on iOS and Android) to run tasks like this with completion guarantees?
            //    e.g. the scheduler could register as a background task when app is put into the background;
            //    the task compeletes when the currently executing command completes.
            //    See https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/BackgroundExecution/BackgroundExecution.html
            //    > Fast completion of downloads is probably more important. In above code, perhaps concentrate
            //      on completing the update first, perform file deletions after, separately?
            
        /* -- end of else after db version check
        }
        */
        [self->_promise resolve:commands];
        return nil;
    })
    .fail(^(id error) {
        NSString *msg = [NSString stringWithFormat:@"Updates download from %@ failed: %@", refreshURL, error ];
        [self->_promise reject:msg];
    });
    
    // Return deferred promise.
    return _promise;
}

@end

@implementation LOCMSCommandProtocolResetDatabase

@synthesize name=_name;

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol {
    self = [super init];
    if (self) {
        _name = QualifiedCommandName(protocol, @"reset");
        _protocol = protocol;
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {
    _promise = [QPromise new];
    
    LOCMSFileDB *fileDB = _protocol.fileDB;
    
    // Delete all reset records
    [fileDB deleteAllResetRecords];
    
    // Generate new reset records for each fileset category.
    // Note that this has to be done /before/ updates are applied, to ensure that the client
    // visible set reflects the state with the pre-updated ACM group ID.
    NSArray *categories = [fileDB performQuery:@"SELECT category FROM fingerprints" withParams:@[]];
    for (NSDictionary *record in categories) {
        NSString *category = record[@"category"];
        if ([@"$group" isEqualToString:category]) {
            continue;
        }
        NSString *cvs = [self buildClientVisibleSetForCategory:category];
        [fileDB insertResetCVS:cvs forCategory:category];
    }
    
    // Read CVS for complete file DB
    NSString *cvs = [self buildClientVisibleSetForCategory:nil];
    
    // Prepare URL, parameters and options for updates request.
    NSString *refreshURL = _protocol.cms.updatesURL;
    NSDictionary *params = @{
        @"secure":  IsSecure,
        @"cvs":     cvs
    };

    NSDictionary *options = @{
        SCHTTPClientRequestOptionAccept:            AcceptMIMETypes,
        SCHTTPClientRequestOptionAcceptEncoding:    AcceptEncodings
    };
    
    // Fetch updates from the server.
    [_protocol.httpClient post:refreshURL data:params options:options]
    .then((id)^(SCHTTPClientResponse *response) {

        LOCMSAuthenticationManager *authManager = self->_protocol.authManager;
        LOCMSFileDB *fileDB = self->_protocol.fileDB;
        
        // Check the response code.
        NSInteger responseCode = response.httpResponse.statusCode;
        if (responseCode == 401) {
            [authManager removeCredentials];
            [self->_promise resolve:@[]];
            return nil;
        }
        
        // Read the updates data.
        id updateData = [response parseData];
        if ([updateData isKindOfClass:[NSString class]]) {
            // Indicates a server error
            NSLog(@"%@ %@", response.httpResponse.URL, updateData);
            [self->_promise resolve:@[]];
            return nil;
        }
        
        // Write updates to database.
        NSDictionary *updates = [updateData valueForKeyPath:@"db"];
        if ([@0 isEqual:updates]) {
            // This can happen no updates to report from the server; replace updates
            // with an empty dictionary.
            updates = @{};
        }
    
        // Start a DB transaction.
        [fileDB beginTransaction];
        
        // Shift current fileset fingerprints to previous.
        [fileDB performUpdate:@"UPDATE filesets SET previous=current" withParams:@[]];

        // Apply all downloaded updates to the database.
        for (NSString *tableName in updates) {
            NSArray *table = updates[tableName];
            for (NSDictionary *values in table) {
                [fileDB upsertValues:values intoTable:tableName];
            }
        }
    
        // Prune ORM related records.
        [fileDB pruneRelatedValues];

        // Commit the transaction.
        [fileDB commitTransaction];
                
        // A list of follow up commands.
        NSMutableArray *commands = [NSMutableArray new];

        // Queue command to delete unused files.
        [commands addObject:@{ @"name": QualifiedCommandName(self->_protocol, @"file-gc"), @"args": @[] }];
        
        // Read list of fileset category names and queue fileset reset commands.
        // (Note that this is done after the updates, and not before, to ensure that any newly
        // visible filesets also get downloaded).
        NSString *command = QualifiedCommandName(self->_protocol, @"reset-fileset");
        NSArray *rs = [fileDB performQuery:@"SELECT category FROM fingerprints" withParams:@[]];
        for (NSDictionary *record in rs) {
            NSString *category = record[@"category"];
            if ([@"$group" isEqualToString:category]) {
                // The ACM group fingerprint entry - skip.
                continue;
            }
            [commands addObject:@{ @"name": command, @"args": @[ category ] }];
        }
            
        [self->_promise resolve:commands];
        return nil;
    })
    .fail(^(id error) {
        NSString *msg = [NSString stringWithFormat:@"Reset download from %@ failed: %@", refreshURL, error ];
        [self->_promise reject:msg];
    });
    
    // Return deferred promise.
    return _promise;
}

- (NSString *)buildClientVisibleSetForCategory:(NSString *)category {

    NSMutableString *json = [NSMutableString new];
    [json appendString:@"{"];
    NSString *separator = @"";
    
    NSArray *records = (category == nil)
        ? [_protocol.fileDB performQuery:@"SELECT id, version FROM files ORDER BY id" withParams:@[]]
        : [_protocol.fileDB performQuery:@"SELECT id, version FROM files WHERE category=? ORDER BY id" withParams:@[ category ]];
    
    for (NSDictionary *record in records) {
        [json appendFormat:@"%@\"%@\":\"%@\"", separator, record[@"id"], record[@"version"]];
        separator = @",";
    }
    [json appendString:@"}"];
    return json;
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
    
    // Build the fileset URL and query parameters.
    NSString *filesetURL = [_protocol.cms urlForFileset:category];
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"secure"] = IsSecure;
    if ([args count] > 1) {
        data[@"since"] = args[1];
    }
    
    // Download the fileset.
    [_protocol.httpClient getFile:filesetURL data:data]
    .then((id)^(SCHTTPClientResponse *response) {
        LOCMSFileDB *fileDB = self->_protocol.fileDB;
        NSInteger responseCode = response.httpResponse.statusCode;
        if (responseCode == 200) {
            // Unzip downloaded file to content location.
            NSString *downloadPath = [response.downloadLocation path];
            NSString *cachePath = [fileDB cacheLocationForFileset:category];
            [SCFileIO unzipFileAtPath:downloadPath toPath:cachePath overwrite:YES];
        }
        if (responseCode == 200 || responseCode == 204) {
            // Update the fileset's fingerprint.
            [fileDB performUpdate:@"UPDATE filesets SET current=latest WHERE category=?" withParams:@[ category ]];
        }
        // Resolve empty list - no follow-on commands.
        [self->_promise resolve:@[]];
        return nil;
    })
    .fail(^(id error) {
        NSString *msg = [NSString stringWithFormat:@"Fileset download from %@ failed: %@", filesetURL, error];
        [self->_promise reject:msg];
    });

    // Return deferred promise.
    return _promise;
}

@end

@implementation LOCMSCommandProtocolResetFileset

@synthesize name=_name;

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol {
    self = [super init];
    if (self) {
        _name = QualifiedCommandName(protocol, @"reset-fileset");
        _protocol = protocol;
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {
    
    _promise = [QPromise new];
    
    LOCMSFileDB *fileDB = _protocol.fileDB;
    
    NSString *category = args[0];
    NSString *cvs = [fileDB getResetCVSForCategory:category];
    
    // If no CVS found then don't continue with this command, but issue a normal fileset
    // download command in its place.
    if (!cvs) {
        id command = QualifiedCommandName(_protocol, @"download-fileset");
        id args = @[ category ];
        [_promise resolve:@[ @{ @"name": command, @"args": args } ]];
    }
    else {
        // Otherwise continue with reset command.
        
        // Build the fileset URL and query parameters.
        NSString *filesetURL = [_protocol.cms urlForFileset:category];
        NSDictionary *data = @{
            @"cvs":     cvs,
            @"secure":  IsSecure
        };
        
        // Download the fileset.
        [_protocol.httpClient post:filesetURL data:data]
        .then((id)^(SCHTTPClientResponse *response) {
            NSInteger responseCode = response.httpResponse.statusCode;
            if (responseCode == 200) {
                // Unzip downloaded file to content location.
                NSString *downloadPath = [response.downloadLocation path];
                NSString *cachePath = [fileDB cacheLocationForFileset:category];
                [SCFileIO unzipFileAtPath:downloadPath toPath:cachePath overwrite:YES];
            }
            if (responseCode == 200 || responseCode == 204) {
                // Update the fileset's fingerprint and delete the fileset reset record
                [fileDB beginTransaction];
                [fileDB performUpdate:@"UPDATE filesets SET current=latest WHERE category=?" withParams:@[ category ]];
                [fileDB deleteResetRecordForCategory:category];
                [fileDB commitTransaction];
            }
            // Resolve empty list - no follow-on commands.
            [self->_promise resolve:@[]];
            return nil;
        })
        .fail(^(id error) {
            NSString *msg = [NSString stringWithFormat:@"Fileset reset from %@ failed: %@", filesetURL, error];
            [self->_promise reject:msg];
        });
    }
    
    // Return deferred promise.
    return _promise;
}

@end

@implementation LOCMSCommandProtocolFileGC

@synthesize name=_name;

- (id)initWithCommandProtocol:(LOCMSCommandProtocol *)protocol {
    self = [super init];
    if (self) {
        _name = QualifiedCommandName(protocol, @"file-gc");
        _protocol = protocol;
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {

    LOCMSFileDB *fileDB = _protocol.fileDB;

    // Remove all files marked as deleted in the file DB.
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

    // Return empty command list.
    return [Q resolve:@[]];
}

@end

