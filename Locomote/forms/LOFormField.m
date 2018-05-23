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
//  Created by Julian Goacher on 12/02/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOFormField.h"
#import "LOFormView.h"
#import "SCAppContainer.h"

@implementation LOFormField

- (id)init {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LOFormFieldReuseID];
    if (self) {
        self.isInput = NO;
        self.height = @45.0f;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.isInput = NO;
        self.height = @45.0f;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setValue:(id)value {
    _value = value;
}

- (void)setTitle:(NSString *)title {
    self.textLabel.text = title;
}

- (NSString *)title {
    return self.textLabel.text;
}

- (UILabel *)titleLabel {
    return self.textLabel;
}

- (BOOL)isSelectable {
    return self.isInput || self.selectAction != nil;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    super.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor {
    return super.backgroundColor;
}

- (BOOL)takeFieldFocus {
    return NO;
}

- (void)releaseFieldFocus {}

- (BOOL)validate {
    return YES;
}

- (void)selectField {
    if (_selectAction) {
        [[SCAppContainer getAppContainer] postMessage:_selectAction sender:self];
    }
}

#pragma mark - Overrides

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

@end
