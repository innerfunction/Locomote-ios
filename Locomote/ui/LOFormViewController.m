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
//  Created by Julian Goacher on 16/02/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOFormViewController.h"

@implementation LOFormViewController

- (id)init {
    self = [super init];
    if (self) {
        _form = [LOFormView new];
        _form.backgroundColor = [UIColor clearColor];
        _form.viewController = self;
        
        self.view = _form;
        self.view.autoresizesSubviews = YES;
        self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    _form.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor {
    return _form.backgroundColor;
}

@end
