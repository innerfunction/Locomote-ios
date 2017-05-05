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
//  Created by Julian Goacher on 30/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOCMSPostsPathRoot.h"
#import "LOCMSFileset.h"
#import "NSDictionary+SC.h"
#import "GRMustache.h"
#import "SCLogger.h"

static SCLogger *Logger;

@implementation LOCMSPostsPathRoot

+ (void)initialize {
    Logger = [[SCLogger alloc] initWithTag:@"LOCMSPostsPathRoot"];
}

- (NSString *)renderPostContent:(NSDictionary *)postData {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *postType = postData[@"posts.type"];
    NSString *postHTML;
    // Resolve the client template to use to render the post.
    NSString *templateFilename = [NSString stringWithFormat:@"_templates/post-%@.html", postType];
    NSString *templatePath = [self.fileDB cacheLocationForFileWithPath:templateFilename];
    if (![fileManager fileExistsAtPath:templatePath]) {
        templatePath = [self.fileDB cacheLocationForFileWithPath:@"_templates/post.html"];
        if (![fileManager fileExistsAtPath:templatePath]) {
            [Logger warn:@"Client template not found for post type %@", postType];
            templatePath = nil;
        }
    }
    if (templatePath) {
        // Load the template and render the post.
        NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
        NSError *error;
        // TODO: Investigate using template repositories to load templates
        // https://github.com/groue/GRMustache/blob/master/Guides/template_repositories.md
        // as they should allow partials to be used within templates, whilst supporting the two
        // use cases of loading templates from file (i.e. for full post html) or evaluating
        // a template from a string (i.e. for post content only).
        postHTML = [GRMustacheTemplate renderObject:postData fromString:template error:&error];
        if (error) {
            [Logger error:@"Rendering %@: %@", templatePath, error];
        }
    }
    if (!postHTML) {
        // If failed to render content then return a default rendering of the post body.
        NSString *postBody = postData[@"posts.body"];
        postHTML = [NSString stringWithFormat:@"<html>%@</html>", postBody];
    }
    return postHTML;
}

- (void)writeEntryContent:(NSDictionary *)content asType:(NSString *)type toResponse:(id<LOContentAuthorityResponse>)response {
    NSString *postHTML = [self renderPostContent:content];
    if ([@"html" isEqualToString:type]) {
        [response respondWithStringData:postHTML mimeType:@"text/html" cachePolicy:NSURLCacheStorageNotAllowed];
    }
    else {
        content = [content extendWith:@{ @"postHTML": postHTML }];
        [super writeEntryContent:content asType:type toResponse:response];
    }
}

@end
