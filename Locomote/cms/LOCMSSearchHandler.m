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

@implementation LOCMSSearchHandler

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {
    
    NSString *text = request.parameters[@"text"];
    NSString *mode = request.parameters[@"mode"];
    NSString *types = request.parameters[@"types"];
    
    NSString *scopeID = request.pathParameters[@"id"];
    
    NSString *tables = self.fileDB.orm.source;
    NSString *where = nil;
    
    NSMutableArray *params = [NSMutableArray new];
    NSString *term = [NSString stringWithFormat:@"%%%@%%", text];
    // TODO 'content' will be on a separate table, how do we know its name?
    if ([@"exact" isEqualToString:mode]) {
        where = @"title LIKE ? OR content LIKE ?";
        [params addObject:term];
        [params addObject:term];
    }
    else {
        NSMutableArray *terms = [NSMutableArray new];
        NSArray *tokens = [term componentsSeparatedByString:@" "];
        for (NSString *token in tokens) {
            // TODO: Trim the token, check for empty tokens.
            NSString *param = [NSString stringWithFormat:@"%%%@%%", token];
            [terms addObject:@"(title LIKE ? OR content LIKE ?)"];
            [params addObject:param];
            [params addObject:param];
        }
        if ([@"any" isEqualToString:mode]) {
            where = [terms componentsJoinedByString:@" OR "];
        }
        else if ([@"all" isEqualToString:mode]) {
            where = [terms componentsJoinedByString:@" AND "];
        }
    }
    if (types) {
        NSArray *typeList = [types componentsSeparatedByString:@","];
        NSString *typeClause;
        if ([typeList count] == 1) {
            typeClause = [NSString stringWithFormat:@"type='%@'", [typeList firstObject]];
        }
        else {
            typeClause = [NSString stringWithFormat:@"type IN ('%@')", [typeList componentsJoinedByString:@"','"]];
        }
        if (where) {
            where = [NSString stringWithFormat:@"(%@) AND %@", where, typeClause];
        }
        else {
            where = typeClause;
        }
    }
    if( !where ) {
        where = @"1=1";
    }
    if (scopeID) {
        NSString *scopePath;
        NSDictionary *row = [self readFileRecordByID:scopeID];
        if (row) {
            scopePath = (NSString *)row[@"path"];
        }
        else {
            // File not found.
            [response respondWithError:makePathNotFoundResponseError(request.path.fullPath)];
            return;
        }

        // Get the path of the directory containing the scoping file.
        scopePath = [scopePath stringByDeletingLastPathComponent];
        // Append a where clause to only include files whose path has the scope path
        // as a prefix.
        NSString *pathWhere = [NSString stringWithFormat:@" AND %@.path LIKE ?", self.fileDB.orm.source];
        NSString *pathParam = [NSString stringWithFormat:@"%%%@", scopePath];
        where = [where stringByAppendingString:pathWhere];
        [params addObject:pathParam];
        //tables = [tables stringByAppendingString:@", closures"];
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT posts.* FROM %@ WHERE %@ LIMIT %ld", tables, where, (long)_searchResultLimit];
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
