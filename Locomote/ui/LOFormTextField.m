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

#import "LOFormTextField.h"
#import "LOFormView.h"

#define Padding             (10.0f)
#define AnimationDuration   (0.33f)
#define InvalidWarningWidth (25.0f)
#define HasValue            ([self.valueLabel length] > 0)

@implementation LOFormTextField

- (id)init {
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:LOFormFieldReuseID];
    if (self) {
        self.isInput = YES;
        self.isEditable = YES;
        
        _inputContentView = [UIView new];
        _input = [UITextField new];
        _input.delegate = self;

        [_inputContentView addSubview:_input];

        _inputContentView.hidden = YES;
        [self addSubview:_inputContentView];
        
        _invalidWarning = [UILabel new];
        _invalidWarning.text = @"\u26A0";
        _invalidWarning.textAlignment = NSTextAlignmentCenter;
        
        _valid = YES;
        
        _defaultTitleAlignment = -1;
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    super.title = title;
    self.textLabel.text = title;
    _input.placeholder = title;
}

- (void)setIsPassword:(BOOL)isPassword {
    _isPassword = isPassword;
    _input.secureTextEntry = isPassword;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Work out which display width to use for the title and value labels.
    // The following is to ensure that labels center and/or align property with or without the presence of
    // accessory views (i.e. disclosure indicators OR invalid field indicators).
    CGRect bounds = self.bounds; // By default, use the full available width.
    if (self.accessoryView != nil && HasValue) {
        // If there is an accessory view and a value then subtract the accessory view's width from the display width.
        CGSize accessorySize = self.accessoryView.frame.size;
        bounds = CGRectMake( bounds.origin.x, bounds.origin.y, bounds.size.width - accessorySize.width, bounds.size.height);
    }
    else if (self.accessoryType != UITableViewCellAccessoryNone && HasValue) {
        // Else if there is an accessory type and a value then just use the content view width.
        bounds = self.contentView.bounds;
    }
    CGRect frame = CGRectInset( bounds, Padding, Padding);
    
    self.textLabel.frame = frame;
    self.detailTextLabel.frame = frame;

    CGFloat x = self.frame.size.width - InvalidWarningWidth;
    _invalidWarning.frame = CGRectMake(x, frame.origin.y, InvalidWarningWidth, frame.size.height);
    
    _inputContentView.frame = self.contentView.bounds;
    _input.frame = frame;
}

- (void)setValue:(id)value {
    // Record the title label's default text alignement if not already recorded.
    if (_defaultTitleAlignment < 0) {
        _defaultTitleAlignment = self.textLabel.textAlignment;
    }
    // Ensure the value is a string.
    if (![value isKindOfClass:[NSString class]]) {
        value = [value description];
    }
    super.value = value;
    self.valueLabel = value;
    // Mark value if field is a password input.
    if (_isPassword) {
        NSMutableString *password = [[NSMutableString alloc] initWithCapacity:[value length]];
        for (NSInteger i = 0; i < [value length]; i++) {
            [password appendString:@"\u25CF"];
        }
        self.valueLabel = password;
    }
    // Display the value.
    dispatch_async(dispatch_get_main_queue(), ^{
        _input.text = value;
        self.textLabel.textAlignment = HasValue ? NSTextAlignmentLeft : _defaultTitleAlignment;
        self.detailTextLabel.text = self.valueLabel;
        // Check whether sufficient room to display both detail and text labels, hide the text label if not.
        CGFloat textWidth = [self.textLabel.text sizeWithAttributes:@{ NSFontAttributeName: self.textLabel.font }].width;
        CGFloat labelWidth = [self.detailTextLabel.text sizeWithAttributes:@{ NSFontAttributeName: self.detailTextLabel.font }].width;
        self.textLabel.hidden = self.contentView.bounds.size.width - labelWidth - textWidth < Padding;
    });
    [self validate];
}

- (BOOL)takeFieldFocus {
    BOOL focusable = _isEditable && self.form.isEnabled;
    if (focusable) {
        // Animate transition to edit view.
        [UIView transitionWithView: self
                          duration: AnimationDuration
                           options: UIViewAnimationOptionTransitionFlipFromTop + UIViewAnimationOptionCurveLinear
                        animations: ^{
                            self.contentView.hidden = YES;
                            _inputContentView.hidden = NO;
                        }
                        completion: ^(BOOL finished) {
                            [_input becomeFirstResponder];
                            if (!_valid) {
                                // TODO: Proper error messages
                                [self.form notifyError:@"Invalid field"];
                            }
                        }];
    }
    return focusable;
}

- (void)releaseFieldFocus {
    if ([_input isFirstResponder]) {
        [_input resignFirstResponder];
        [UIView transitionWithView: self
                          duration: AnimationDuration
                           options: UIViewAnimationOptionTransitionFlipFromTop + UIViewAnimationOptionCurveLinear
                        animations: ^{
                            self.contentView.hidden = NO;
                            _inputContentView.hidden = YES;
                        }
                        completion: ^(BOOL finished) {
                        }];
    }
}

- (BOOL)validate {
    _valid = YES;
    if (_isRequired && [self.value length] == 0) {
        _valid = NO;
    }
    else if (_hasSameValueAs) {
        id otherValue = [self.form getFieldValue:_hasSameValueAs];
        if (otherValue == nil) {
            _valid = self.value == nil;
        }
        else {
            _valid = [self.value isEqual:otherValue];
        }
    }
    if (_valid) {
        self.accessoryView = nil;
    }
    else {
        self.accessoryView = _invalidWarning;
    }
    return _valid;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.value = textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    self.value = textField.text;
    [self.form moveFocusToNextField];
    return NO;
}

@end
