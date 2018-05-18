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

#import "LOCMSRequestHandler.h"

@implementation LOCMSRequestHandler

- (id)initWithRepository:(LOCMSRepository *)repository {
    self = [super init];
    self.fileDB = repository.fileDB;
    self.filesets = repository.filesets;
    return self;
}

- (NSDictionary *)readFileRecordByID:(NSString *)fileID {
    return [self readFileRecordByID:fileID inCategory:nil];
}

- (NSDictionary *)readFileRecordByID:(NSString *)fileID inCategory:(NSString *)category {

    NSMutableArray *wheres = [NSMutableArray new];
    NSMutableArray *values = [NSMutableArray new];
    NSArray *mappings = @[];
    
    [wheres addObject:[NSString stringWithFormat:@"%@.id = ?", _fileDB.orm.source]];
    [values addObject:fileID];
    
    // If category specified then include fileset mappings.
    if (category) {
        LOCMSFileset *fileset = _filesets[category];
        if (!fileset) {
            return nil;
        }
        [wheres addObject:[NSString stringWithFormat:@"%@.category = ?", _fileDB.orm.source]];
        [values addObject:category];
        mappings = fileset.mappings;
    }

    // Query for the file record.
    NSString *where = [wheres componentsJoinedByString:@" AND "];
    NSArray *result = [_fileDB.orm selectWhere:where values:values mappings:mappings];
    if ([result count] > 0) {
        return result[0];
    }
    
    // Record not found.
    return nil;
}

- (NSDictionary *)readFileRecordByPath:(NSString *)path {
    
    NSString *where = [NSString stringWithFormat:@"%@.path = ?", _fileDB.orm.source];
    NSArray *values = @[ path ];
    
    NSArray *result = [_fileDB.orm selectWhere:where values:values mappings:@[]];
    if ([result count] > 0) {
        return result[0];
    }
    
    // Record not found.
    return nil;
}

#pragma mark - LOCMSRequestHandler

- (void)handleRequest:(id<LOContentRequest>)request response:(id<LOContentResponse>)response {
    // Do-nothing implementation - this class should be sub-classed.
}

@end
