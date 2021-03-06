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
#import "LOCMSRequestHandler.h"
#import "LORequestDispatcher.h"

/**
 * A request handler for performing full-text searches.
 *
 * Implementation note: Searches can only be performed on pages, which are a file
 * type whose content is stored within the file database. Specifically, the file
 * content must be stored in a table named 'pages' which has 'title' and 'content'
 * fields, and these names are currently hardcoded.
 */
@interface LOCMSSearchHandler : LOCMSRequestHandler

/// The maximum number of search results to return.
@property (nonatomic, assign) NSInteger searchResultLimit;

@end
