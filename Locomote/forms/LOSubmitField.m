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
//  Created by Julian Goacher on 23/02/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOSubmitField.h"
#import "LOFormView.h"

@implementation LOSubmitField

- (id)init {
    self = [super init];
    if (self) {
        _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _loadingIndicator.hidden = YES;
        [self.contentView addSubview:_loadingIndicator];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _loadingIndicator.frame = self.contentView.bounds;
}

- (BOOL)isSelectable {
    return YES;
}

- (void)selectField {
    [self.form submit];
}

- (void)showFormLoading:(BOOL)loading {
    if (loading) {
        [_loadingIndicator startAnimating];
    }
    else {
        [_loadingIndicator stopAnimating];
    }
    self.textLabel.hidden = loading;
}

@end
