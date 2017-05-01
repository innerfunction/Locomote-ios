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
//  Created by Julian Goacher on 23/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOCMSFilesetCategoryPathRoot.h"
#import "LOContentProvider.h"
#import "LOCMSRepository.h"
#import "LOCMSFileset.h"
#import "LOContentTypeConverter.h"
#import "SCDBORM.h"
#import "SCHTTPClient.h"
#import "SCMIMETypes.h"

@implementation LOCMSFilesetCategoryPathRoot

- (id)initWithFileset:(LOCMSFileset *)fileset repository:(LOCMSRepository *)repository {
    self = [super init];
    if (self) {
        self.fileset = fileset;
        self.repository = repository;
    }
    return self;
}

- (void)setRepository:(LOCMSRepository *)repository {
    _repository = repository;
    _fileDB = repository.fileDB;
}

- (NSArray *)queryWithParameters:(NSDictionary *)parameters {

    NSMutableArray *wheres = [NSMutableArray new];
    NSMutableArray *values = [NSMutableArray new];
    NSArray *mappings = @[];
    
    // Note that category field is qualifed by source table name.
    if (_fileset) {
        [wheres addObject:[NSString stringWithFormat:@"%@.category = ?", _fileDB.orm.source]];
        [values addObject:_fileset.category];
        mappings = _fileset.mappings;
    }
    
    // Add filters for each of the specified parameters.
    for (id key in [parameters keyEnumerator]) {
        // Note that parameter names must be qualified by the correct relation name.
        [wheres addObject:[NSString stringWithFormat:@"%@ = ?", key]];
        [values addObject:parameters[key]];
    }
    
    // Join the wheres into a single where clause.
    NSString *where = [wheres componentsJoinedByString:@" AND "];
    // Execute query and return result.
    return [_fileDB.orm selectWhere:where values:values mappings:mappings];
}

- (NSDictionary *)entryWithKey:(NSString *)key {
    // Read the content and return the result.
    return [_fileDB.orm selectKey:key mappings:_fileset.mappings];
}

- (NSDictionary *)entryWithPath:(NSString *)path {
    NSArray *result = [_fileDB.orm selectWhere:@"path = ?" values:@[ path ] mappings:_fileset.mappings];
    return [result count] > 0 ? result[0] : nil;
}

- (void)writeQueryContent:(NSArray *)content asType:(NSString *)type toResponse:(id<LOContentAuthorityResponse>)response {
    if (type) {
        id<LOContentTypeConverter> typeConverter = self.repository.queryTypes[type];
        if (typeConverter) {
            [typeConverter writeContent:content toResponse:response];
        }
        else {
            [response respondWithError:makeUnsupportedTypeResponseError(type)];
        }
    }
    else {
        [response respondWithJSONData:content cachePolicy:NSURLCacheStorageNotAllowed];
    }
}

- (void)writeEntryContent:(NSDictionary *)content asType:(NSString *)type toResponse:(id<LOContentAuthorityResponse>)response {
    if (type) {
        id<LOContentTypeConverter> typeConverter = self.repository.recordTypes[type];
        if (typeConverter) {
            [typeConverter writeContent:content toResponse:response];
        }
        else {
            // No specific type converter found. Check if the content file type is compatible
            // with the requested type and that fileset info is available.
            NSString *path = content[@"path"];
            NSString *ext = [path pathExtension];
            if (_fileset && [type isEqualToString:ext]) {
                NSString *mimeType = [SCMIMETypes mimeTypeForType:type];
                NSString *url = [_repository.cms urlForFile:path];
                NSString *cachePath = [_fileDB cacheLocationForFile:content];
                BOOL cachable = [self.fileset cachable];
                // Check if a local copy of the file exists in the cache.
                if (cachable && [[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
                    // Local copy found, respond with contents.
                    [response respondWithFileData:cachePath
                                         mimeType:mimeType
                                      cachePolicy:NSURLCacheStorageNotAllowed];
                }
                else {
                    // No local copy found, download from server.
                    SCHTTPClient *httpClient = _repository.httpClient;
                    [httpClient getFile:url]
                    .then((id)^(SCHTTPClientResponse *httpResponse) {
                        NSString *downloadPath = [httpResponse.downloadLocation path];
                        NSError *error = nil;
                        // If cachable then move file to cache.
                        if (cachable) {
                            NSFileManager *fileManager = [NSFileManager defaultManager];
                            // Ensure that the target directory exists.
                            NSString *cacheDir = [cachePath stringByDeletingLastPathComponent];
                            [fileManager createDirectoryAtPath:cacheDir
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error];
                            if (!error) {
                                [fileManager moveItemAtPath:downloadPath
                                                     toPath:cachePath
                                                      error:&error];
                            }
                        }
                        if (error) {
                            [response respondWithError:error];
                        }
                        else {
                            // Respond with file contents.
                            NSString *contentPath = cachable ? cachePath : downloadPath;
                            [response respondWithFileData:contentPath
                                                 mimeType:mimeType
                                              cachePolicy:NSURLCacheStorageNotAllowed];
                        }
                        return nil;
                    })
                    .fail(^(id err) {
                        NSError *error;
                        if ([err isKindOfClass:[NSError class]]) {
                            error = (NSError *)err;
                        }
                        else {
                            NSString *description = [err description];
                            // See http://nshipster.com/nserror/
                            error = [NSError errorWithDomain:NSURLErrorDomain
                                                        code:NSURLErrorResourceUnavailable
                                                    userInfo:@{ NSLocalizedDescriptionKey: description }];
                        }
                        [response respondWithError:error];
                    });
                }
            }
            else {
                [response respondWithError:makeUnsupportedTypeResponseError(type)];
            }
        }
    }
    else {
        [response respondWithJSONData:content cachePolicy:NSURLCacheStorageNotAllowed];
    }
}

#pragma mark - LOContentAuthorityPathRoot

- (void)writeResponse:(id<LOContentAuthorityResponse>)response
         forAuthority:(id<LOContentAuthority>)authority
                 path:(LOContentPath *)path
           parameters:(NSDictionary *)parameters {
    
    if ([path isEmpty]) {
        // Content path references a content query.
        NSString *type = [path ext];
        NSArray *content = [self queryWithParameters:parameters];
        [self writeQueryContent:content asType:type toResponse:response];
    }
    else {
        // Content path references a resource (i.e. file entry). The resource identifier can be
        // in the format ${key}.{type}; i.e. if prefixed with a dollar symbol then the resource is
        // referenced by file ID and has a type modifier. Otherwise, the relative portion of the path
        // at this point can be used to reference a resource by its file path.
        NSDictionary *entry = nil;
        NSString *head = [path root];
        NSString *type = [path ext];
        // Check for reference by ID.
        if ([head hasPrefix:@"$"] && [[path components] count] == 1) {
            NSString *key = [head substringFromIndex:1];
            entry = [self entryWithKey:key];
        }
        // If no content yet then may be referenced by file path.
        if (!entry) {
            entry = [self entryWithPath:[path relativePath]];
        }
        // If now have an entry then return it, else return an error.
        if (entry) {
            [self writeEntryContent:entry asType:type toResponse:response];
        }
        else {
            [response respondWithError:makeInvalidPathResponseError([path fullPath])];
        }
    }
}

@end
