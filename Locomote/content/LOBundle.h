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
//  Created by Julian Goacher on 02/05/2017.
//  Copyright © 2017 Locomote.sh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOContentProvider.h"

/**
 * A subclass of NSBundle that allows access to resources through the Locomote content provider.
 * Note that this only works reliably for resources that have been packaged with the app, or
 * which are published with through the Locomote CMS with a fileset cache policy of 'app'.
 * No guarantees can be made for resources published to the content cache, as these might not
 * be downloaded, or may have been cleared from the cache at the time of request.
 */
@interface LOBundle : NSBundle {
    NSBundle *_mainBundle;
    LOContentProvider *_provider;
}

+ (LOBundle *)locomoteBundle;

@end
