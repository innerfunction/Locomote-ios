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

#import "LOCMSFileListHandler.h"
#import "LOContentAuthority.h"

@implementation LOCMSFileListHandler

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {

    NSMutableArray *wheres = [NSMutableArray new];
    NSMutableArray *values = [NSMutableArray new];
    NSArray *mappings = @[];

    // A reference file ID.
    NSString *fid = request.pathParameters[@"id"];
    // A fileset category.
    NSString *category = request.pathParameters[@"category"];
    // A file relation - sibling, child or descendent.
    NSString *relation = request.pathParameters[@"relation"];
    // Reference file path.
    NSString *refPath = @"";
    
    // If a file ID is specified then read a reference file path from the file record.
    if (fid) {
        // Read the file path.
        NSDictionary *row = [self readFileRecordByID:fid];
        if (row) {
            refPath = (NSString *)row[@"path"];
        }
        else {
            // File not found.
            [response respondWithError:makePathNotFoundResponseError(request.path.fullPath)];
            return;
        }
    }
    
    // If category specified then include fileset bindings.
    if (category) {
        LOCMSFileset *fileset = self.filesets[category];
        if (!fileset) {
            // Fileset category not found.
            [response respondWithError:makePathNotFoundResponseError(request.path.fullPath)];
            return;
        }
        // Note that category field is qualifed by source table name.
        [wheres addObject:[NSString stringWithFormat:@"%@.category = ?", self.fileDB.orm.source]];
        [values addObject:category];
        mappings = fileset.mappings;
    }
    
    // Add filters for each of the specified parameters.
    NSDictionary *parameters = request.parameters;
    for (id key in [parameters keyEnumerator]) {
        // Note that parameter names must be qualified by the correct relation name.
        [wheres addObject:[NSString stringWithFormat:@"%@ = ?", key]];
        [values addObject:parameters[key]];
    }

    // Join the wheres into a single where clause.
    NSString *where = [wheres componentsJoinedByString:@" AND "];
    // Execute query.
    NSArray *result = [self.fileDB.orm selectWhere:where values:values mappings:mappings];
    // Apply relation filter.
    if ([@"siblings" isEqualToString:relation]) {
        result = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id item, NSDictionary *bindings) {
            NSDictionary *row = (NSDictionary *)item;
            id rid = row[@"id"];
            if ([fid isEqualToString:rid]) {
                // Reference file can't be its own sibling.
                return NO;
            }
            NSString *itemPath = (NSString *)row[@"path"];
            NSString *itemDir  = [itemPath stringByDeletingLastPathComponent];
            // File is a sibling if it shares the same reference path (i.e. directory) as the reference file.
            return [refPath isEqualToString:itemDir];
        }]];
    }
    else if ([@"children" isEqualToString:relation]) {
        result = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id item, NSDictionary *bindings) {
            NSDictionary *row   = (NSDictionary *)item;
            NSString *itemPath  = (NSString *)row[@"path"];
            NSString *parentDir = [[itemPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
            // File is a child if its parent directory of its direcoty is the
            // same reference path (i.e. directory) as the reference file.
            return [refPath isEqualToString:parentDir];
        }]];
    }
    else if ([@"descendents" isEqualToString:relation]) {
        result = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id item, NSDictionary *bindings) {
            NSDictionary *row = (NSDictionary *)item;
            id rid = row[@"id"];
            if ([fid isEqualToString:rid]) {
                // Reference file can't be its own descendent.
                return NO;
            }
            NSString *itemPath = (NSString *)row[@"path"];
            // File is a descendent if its path has the reference path as a prefix.
            return [itemPath hasPrefix:refPath];
        }]];
    }
    
    // Return the result.
    [response respondWithJSONData:result cachePolicy:NSURLCacheStorageNotAllowed];
}

@end
