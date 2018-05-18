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

#import <Foundation/Foundation.h>
#import "LORequestDispatcher.h"
#import "LOCMSFileDB.h"
#import "LOCMSFileset.h"
#import "LOCMSRepository.h"

/**
 * A superclass for all CMS request handlers.
 */
@interface LOCMSRequestHandler : NSObject <LORequestHandler> {
    LOCMSFileDB *_fileDB;
    NSDictionary<NSString *, LOCMSFileset *> *_filesets;
}

- (id)initWithRepository:(LOCMSRepository *)repository;

/// Read a file record by file ID.
- (NSDictionary *)readFileRecordByID:(NSString *)fileID;
/// Read a file record by file ID and with specified category bindings.
- (NSDictionary *)readFileRecordByID:(NSString *)fileID inCategory:(NSString *)category;
/// Read a file record by file path.
- (NSDictionary *)readFileRecordByPath:(NSString *)path;

@end
