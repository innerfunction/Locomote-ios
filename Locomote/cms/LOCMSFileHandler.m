// Copyright 2018 InnerFunction Ltd.
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
//  Created by Julian Goacher on 17/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import "LOCMSFileHandler.h"
#import "LOMIMETypes.h"
#import "GRMustache.h"
#import "SCLogger.h"

static SCLogger *Logger;

@interface LOCMSFileHandler ()

/// Render a page's content.
- (NSString *)renderPageContent:(NSDictionary *)record;
/// Write a file's content to a response.
- (void)writeFileContent:(NSDictionary *)record toResponse:(id<LOContentResponse>)response;

@end

@implementation LOCMSFileHandler

+ (void)initialize {
    Logger = [[SCLogger alloc] initWithTag:@"LOCMSFileHandler"];
}

- (id)initWithRepository:(LOCMSRepository *)repository {
    self = [super initWithRepository:repository];
    if (self) {
        _repository = repository;
    }
    return self;
}

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {

    NSDictionary *record = nil;
    
    // The reference mode.
    NSString *mode = request.pathParameters[@"mode"];
    if (!mode) {
        mode = @"record";
    }
    // A reference file ID.
    NSString *fileID = request.pathParameters[@"id"];
    // Check whether to qualify by fileset category.
    NSString *category = request.pathParameters[@"category"];

    // If a file ID specified then read the file record using it.
    if (fileID) {
        // Read the file record.
        record = [self readFileRecordByID:fileID inCategory:category];
    }
    else {
        // If no file ID specified then the entire request path is assumed to be the path of the
        // required file; read the file record by file path.
        record = [self readFileRecordByPath:request.path];
        // Reference mode is always 'content' for files referenced by path.
        mode = @"content";
    }

    if (!record) {
        // File not found.
        [response respondWithError:makePathNotFoundResponseError(request.path)];
        return;
    }
    // Check if we have the file category - if not then we need to reload the file
    // record so that fileset mappings are included.
    if (!category) {
        fileID   = record[@"id"];
        category = record[@"category"];
        record = [self readFileRecordByID:fileID inCategory:category];
    }

    // Send the response.
    if ([@"record" isEqualToString:mode]) {
        [response respondWithJSONData:record cachePolicy:NSURLCacheStorageNotAllowed];
    }
    else if ([@"content" isEqualToString:mode]) {
        // If the file data has a 'page' property then render the file's contents using
        // a client template.
        if (record[@"page"]) {
            NSString *content = [self renderPageContent:record];
            // Note for now the assumption that all page content is HTML.
            [response respondWithStringData:content
                                   mimeType:@"text/html"
                                cachePolicy:NSURLCacheStorageNotAllowed];
        }
        else {
            [self writeFileContent:record toResponse:response];
        }
    }
}

- (NSString *)renderPageContent:(NSDictionary *)record {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *pageData = record[@"page"];
    NSString *pageType = pageData[@"type"];
    NSString *pageHTML;
    // Resolve the client template to use to render the post.
    // TODO: Note that the following code assumes the page templates are avaiable in the app
    // cache; consider whether to instead load templates via the content: URL.
    NSString *templateFilename = [NSString stringWithFormat:@"_templates/page-%@.html", pageType];
    NSString *templatePath = [self.fileDB cacheLocationForFile:templateFilename];
    if (!(templatePath && [fileManager fileExistsAtPath:templatePath])) {
        templatePath = [self.fileDB cacheLocationForFile:@"_templates/page.html"];
        if (!(templatePath && [fileManager fileExistsAtPath:templatePath])) {
            [Logger warn:@"Client template not found for page type %@", pageType];
            templatePath = nil;
        }
    }
    // If template found then use to render the page content.
    if (templatePath) {
        NSError *error;
        // Load the template and render the post.
        NSString *template = [NSString stringWithContentsOfFile:templatePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
        if (!error) {
            // TODO: Investigate using template repositories to load templates
            // https://github.com/groue/GRMustache/blob/master/Guides/template_repositories.md
            // as they should allow partials to be used within templates, whilst supporting the two
            // use cases of loading templates from file (i.e. for full post html) or evaluating
            // a template from a string (i.e. for post content only).
            pageHTML = [GRMustacheTemplate renderObject:pageData
                                             fromString:template
                                                  error:&error];
        }
        if (error) {
            [Logger error:@"Rendering %@: %@", templatePath, error];
        }
    }
    // If no page content yet then just wrap what we have in <html> tags.
    if (!pageHTML) {
        // If failed to render content then return a default rendering of the post body.
        NSString *pageContent = pageData[@"content"];
        pageHTML = [NSString stringWithFormat:@"<html>%@</html>", pageContent];
    }
    return pageHTML;
}

- (void)writeFileContent:(NSDictionary *)record toResponse:(id<LOContentResponse>)response {
    // Read the fileset.
    NSString *category    = record[@"category"];
    LOCMSFileset *fileset = self.filesets[category];
    if (!fileset) {
        [response respondWithError:makeInvalidCategoryResponseError(category)];
        return;
    }
    // Check if the file is cacheable.
    BOOL cachable       = [fileset cachable];
    // Read the file type from it's file extension.
    NSString *path      = record[@"path"];
    NSString *ext       = [path pathExtension];
    NSString *mimeType  = [LOMIMETypes mimeTypeForType:ext];
    // Read the cache location.
    NSString *cachePath = [self.fileDB cacheLocationForFileRecord:record];
    // Check if a local copy of the file exists in the cache.
    if (cachable && [[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        // Local copy found, respond with contents.
        [response respondWithFileData:cachePath
                             mimeType:mimeType
                          cachePolicy:NSURLCacheStorageNotAllowed];
        return;
    }
    // Read the file's server-side URL.
    NSString *url = [_repository.cms urlForFile:path];
    // Read the cache location for downloaded content (note that the cacheLocationForFileRecord:
    // may return a path to the app bundle if the content was packaged).
    cachePath = [self.fileDB cacheLocationForFile:path inFileset:category];
    // No local copy found, download from server.
    SCHTTPClient *httpClient = _repository.httpClient;
    [httpClient getFile:url]
    .then((id)^(SCHTTPClientResponse *httpResponse) {
        NSString *downloadPath = [httpResponse.downloadLocation path];
        NSError *error = nil;
        // If cachable then move file to cache.
        if (cachable) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:cachePath]) {
                // Remove any file already at the target location.
                [fileManager removeItemAtPath:cachePath error:&error];
            }
            else {
                // Ensure that the target directory exists.
                NSString *cacheDir = [cachePath stringByDeletingLastPathComponent];
                [fileManager createDirectoryAtPath:cacheDir
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:&error];
            }
            if (!error) {
                // Move the file to the cache location.
                [fileManager moveItemAtPath:downloadPath
                                     toPath:cachePath
                                      error:&error];
            }
            if (!error) {
                // Update the file's cache status.
                [self.fileDB markFileAsDownloaded:path];
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
        // HTTP request failed, package error and send to response.
        NSError *error;
        if ([err isKindOfClass:[NSError class]]) {
            error = (NSError *)err;
        }
        else {
            NSString *description = [err description];
            error = [NSError errorWithDomain:NSURLErrorDomain
                                        code:NSURLErrorResourceUnavailable
                                    userInfo:@{ NSLocalizedDescriptionKey: description }];
        }
        [response respondWithError:error];
    });
}

@end
