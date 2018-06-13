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

#import "LOCMSSearchHandler.h"
#import "LOContentAuthority.h"
#import "NSDictionary+SC.h"

#define PAGE_TABLE                  (@"pages")
#define DEFAULT_SEACH_RESULT_LIMIT  (100);

@implementation LOCMSSearchHandler

- (id)initWithRepository:(LOCMSRepository *)repository {
    self = [super initWithRepository:repository];
    self.searchResultLimit = DEFAULT_SEACH_RESULT_LIMIT;
    return self;
}

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {
    
    // The text being searched for.
    NSString *text    = request.parameters[@"text"];
    // The search mode - exact, any or all.
    NSString *mode    = request.parameters[@"mode"];
    // The file types to include in the search.
    NSString *types   = request.parameters[@"types"];
    // An optional search scope; if specified then only descendents of the specified file
    // are searched; file descendents are any file whose path has the reference file's
    // directory path as a prefix.
    NSString *scopeID = request.pathParameters[@"id"];
    
    // Two main tables are the source table (e.g. 'files') and the page table (e.g. 'pages').
    // Note that page table names are currently hardcoded.
    NSArray *tables = @[ self.fileDB.orm.source, PAGE_TABLE ];
    NSArray *wheres = @[ [NSString stringWithFormat:@"%@.id = %@.id", self.fileDB.orm.source, PAGE_TABLE ]];
    
    NSMutableArray *params = [NSMutableArray new];
    NSString *term = [NSString stringWithFormat:@"%%%@%%", text];
    if ([@"exact" isEqualToString:mode]) {
        NSString * where = [NSString stringWithFormat:@"%@.title LIKE ? OR %@.content LIKE ?", PAGE_TABLE, PAGE_TABLE];
        wheres = [wheres arrayByAddingObject:where];
        [params addObject:term];
        [params addObject:term];
    }
    else {
        NSMutableArray *terms = [NSMutableArray new];
        NSArray *tokens = [term componentsSeparatedByString:@" "];
        for (NSString *token in tokens) {
            NSString *trimmedToken = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([trimmedToken length] > 0) {
                NSString *term = [NSString stringWithFormat:@"(%@.title LIKE ? OR %@.content LIKE ?)", PAGE_TABLE, PAGE_TABLE];
                [terms addObject:term];
                NSString *param = [NSString stringWithFormat:@"%%%@%%", trimmedToken];
                [params addObject:param];
                [params addObject:param];
            }
        }
        NSString *where;
        if ([@"any" isEqualToString:mode]) {
            where = [terms componentsJoinedByString:@" OR "];
        }
        else if ([@"all" isEqualToString:mode]) {
            where = [terms componentsJoinedByString:@" AND "];
        }
        wheres = [wheres arrayByAddingObject:where];
    }
    
    if (types) {
        NSArray *typeList = [types componentsSeparatedByString:@","];
        NSString *typeClause;
        if ([typeList count] == 1) {
            typeClause = [NSString stringWithFormat:@"%@.type='%@'", PAGE_TABLE, [typeList firstObject]];
        }
        else {
            typeClause = [NSString stringWithFormat:@"%@.type IN ('%@')", PAGE_TABLE, [typeList componentsJoinedByString:@"','"]];
        }
        wheres = [wheres arrayByAddingObject:typeClause];
    }
    
    if (scopeID) {
        NSString *scopePath;
        NSDictionary *row = [self readFileRecordByID:scopeID];
        if (row) {
            scopePath = (NSString *)row[@"path"];
        }
        else {
            // File not found.
            [response respondWithError:makePathNotFoundResponseError(request.path)];
            return;
        }
        // Get the path of the directory containing the scoping file.
        scopePath = [scopePath stringByDeletingLastPathComponent];
        // Append a where clause to only include files whose path has the scope path
        // as a prefix.
        NSString *where = [NSString stringWithFormat:@" AND %@.path LIKE ?", self.fileDB.orm.source];
        NSString *param = [NSString stringWithFormat:@"%%%@", scopePath];
        wheres = [wheres arrayByAddingObject:where];
        [params addObject:param];
    }
    
    NSString *where = [wheres componentsJoinedByString:@") AND ("];
    NSString *_tables = [tables componentsJoinedByString:@","];
    NSString *sql = [NSString stringWithFormat:@"SELECT %@.* FROM %@ WHERE (%@) LIMIT %ld", PAGE_TABLE, _tables, where, (long)_searchResultLimit];
    NSArray *rows = [self.fileDB performQuery:sql withParams:params];
    // Add search information to each result item.
    NSMutableArray *result = [NSMutableArray new];
    NSDictionary *searchInfo = @{
        @"searchText": text,
        @"searchMode": mode
    };
    for (NSDictionary *row in rows) {
        [result addObject:[row extendWith:searchInfo]];
    }

    // Send the result.
    [response respondWithJSONData:result cachePolicy:NSURLCacheStorageNotAllowed];
}

@end
