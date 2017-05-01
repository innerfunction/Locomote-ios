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
//  Created by Julian Goacher on 08/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOContentAuthority.h"

NSError *makePathNotFoundResponseError(NSString *path) {
    NSString *description = [NSString stringWithFormat:@"Path not found: %@", path];
    // See http://nshipster.com/nserror/
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorFileDoesNotExist // Alternatively: NSURLErrorResourceUnavailable
                                     userInfo:@{ NSLocalizedDescriptionKey: description }];
    return error;
}

NSError *makeInvalidPathResponseError(NSString *path) {
    NSString *description = [NSString stringWithFormat:@"Invalid path: %@", path];
    // See http://nshipster.com/nserror/
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorFileDoesNotExist // Alternatively: NSURLErrorResourceUnavailable
                                     userInfo:@{ NSLocalizedDescriptionKey: description }];
    return error;
}

NSError *makeUnsupportedTypeResponseError(NSString *type) {
    NSString *description = [NSString stringWithFormat:@"Unsupported type: %@", type];
    // See http://nshipster.com/nserror/
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorResourceUnavailable
                                     userInfo:@{ NSLocalizedDescriptionKey: description }];
    return error;
}
