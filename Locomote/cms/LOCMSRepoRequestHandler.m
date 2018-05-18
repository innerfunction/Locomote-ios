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

#import "LOCMSRepoRequestHandler.h"
#import "LOCMSFileListHandler.h"
#import "LOCMSFileHandler.h"
#import "LOCMSSearchHandler.h"
#import "LOCMSRepository.h"

#define RequestMapping(_path,_handler) ([[LORequestHandlerMapping alloc] initWithPath:_path handler:_handler])

@implementation LOCMSRepoRequestHandler

@synthesize requestHandlers=_requestHandlers;

- (id)initWithRepository:(LOCMSRepository *)repository {
    self = [super init];
    if (self) {
        LOCMSFileHandler *fileHandler = [[LOCMSFileHandler alloc] initWithRepository:repository];
        LOCMSFileListHandler *fileListHandler = [[LOCMSFileListHandler alloc] initWithRepository:repository];
        LOCMSSearchHandler *searchHandler = [[LOCMSSearchHandler alloc] initWithRepository:repository];
        self.requestHandlers = @[
            // Read file contents.
            RequestMapping(@"files.api/{id}(/{mode:content})?", fileHandler ),
            // List siblings / children / descendents of a file.
            RequestMapping(@"files.api/{id}/{relation:siblings|children|descendents}", fileListHandler ),
            // List all files.
            RequestMapping(@"files.api", fileListHandler ),
            // Read file contents within a fileset category.
            RequestMapping(@"fileset.api/{category}/{id}(/{mode:content})?", fileHandler ),
            // List siblings / children / descendents of a file within a fileset category.
            RequestMapping(@"fileset.api/{category}/{id}/{relation:siblings|children|descendents}", fileListHandler ),
            // Listfiles within a fileset category.
            RequestMapping(@"fileset.api/{category}", fileListHandler ),
            // Do a file search.
            RequestMapping(@"search.api", searchHandler ),
            // Read a file by path.
            RequestMapping(@"**", fileHandler )
        ];
    }
    return self;
}

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {
    [_dispatcher dispatchRequest:request response:response];
}

@end
