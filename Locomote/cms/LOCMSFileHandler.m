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

@implementation LOCMSFileHandler

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {

    NSMutableArray *wheres = [NSMutableArray new];
    NSMutableArray *values = [NSMutableArray new];
    NSArray *mappings = @[];
    
    // The reference mode.
    NSString *mode = request.pathParameters[@"mode"];
    if (!mode) {
        mode = @"record";
    }
    // A reference file ID.
    NSString *fid = request.pathParameters[@"id"];
    
    // If a file ID specified then read the file record using it.
    if (fid) {
        
        // Lookup the record by ID.
        [wheres addObject:[NSString stringWithFormat:@"%@.id = ?", _fileDB.orm.source]];
        [values addObject:fid];
        
        // Check whether to qualify by fileset category.
        NSString *category = request.pathParameters[@"category"];
        // If category specified then include fileset bindings.
        if (category) {
            LOCMSFileset *fileset = _filesets[category];
            if (!fileset) {
                // Fileset category not found.
                [response respondWithError:makePathNotFoundResponseError(request.path.fullPath)];
                return;
            }
            // Note that category field is qualifed by source table name.
            [wheres addObject:[NSString stringWithFormat:@"%@.category = ?", _fileDB.orm.source]];
            [values addObject:category];
            mappings = fileset.mappings;
        }
    }
    else {
        // If no file ID specified then the entire request path is assumed to be the path of the
        // required file.
        [wheres addObject:[NSString stringWithFormat:@"%@.path = ?", _fileDB.orm.source]];
        [values addObject:request.path.fullPath];

        // Reference mode is always 'content' for files referenced by path.
        mode = @"content";
    }
    
    // Join the wheres into a single where clause.
    NSString *where = [wheres componentsJoinedByString:@" AND "];

    // Read file record.
    NSDictionary *record = nil;
    NSArray *result = [_fileDB.orm selectWhere:where values:@[ fid ] mappings:mappings];
    if ([result count] > 0) {
        record = result[0];
    }
    if (!record) {
        // File not found.
        [response respondWithError:makePathNotFoundResponseError(request.path.fullPath)];
    }
    
    if ([@"record" isEqualToString:mode]) {
        [response respondWithJSONData:result cachePolicy:NSURLCacheStorageNotAllowed];
    }
    else if ([@"content" isEqualToString:mode]) {
        // TODO Resolve file content from appropriate cache, apply any content processing and return result.
    }

}

@end
