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

#import "LOFormView.h"
#import "LOFormField.h"
#import "LOFormTextField.h"
#import "LOFormImageField.h"
#import "SCAppContainer.h"
#import "SCConfiguration.h"
#import "SCStringTemplate.h"

@implementation LOFormView

- (id)init {
    self = [super init];
    if (self) {
        self.dataSource = self;
        self.delegate = self;
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        _isEnabled = YES;
    }
    return self;
}

- (void)setFields:(NSArray *)fields {
    _fields = fields;
    NSMutableDictionary *defaultValues = [NSMutableDictionary new];
    for (LOFormField *field in _fields) {
        field.form = self;
        if (field.name) {
            if (field.value != nil) {
                [defaultValues setObject:field.value forKey:field.name];
            }
        }
        if ([field conformsToProtocol:@protocol(LOFormLoadingIndicator)]) {
            _loadingIndicator = (id<LOFormLoadingIndicator>)field;
        }
    }
    _defaultValues = defaultValues;
    // If input values have already been set then set again so that field values are populated.
    if (_inputValues) {
        self.inputValues = _inputValues;
    }
}

- (void)setMethod:(NSString *)method {
    _method = [method uppercaseString];
}

- (void)setInputValues:(NSDictionary *)inputValues {
    _inputValues = inputValues;
    for (LOFormField *field in _fields) {
        if (field.name) {
            id value = inputValues[field.name];
            if (value != nil) {
                field.value = (value == [NSNull null] ? nil : value);
            }
        }
    }
}

- (NSDictionary *)inputValues {
    NSMutableDictionary *values = [NSMutableDictionary new];
    for (LOFormField *field in _fields) {
        if (field.isInput && field.name && field.value != nil) {
            values[field.name] = field.value;
        }
    }
    return values;
}

#pragma mark - Instance methods

- (NSString *)getFieldValue:(NSString *)name {
    for (LOFormField *field in _fields) {
        if ([field.name isEqualToString:name]) {
            return field.value;
        }
    }
    return nil;
}

- (LOFormField *)getFocusedField {
    return (LOFormField *)_fields[_focusedFieldIdx];
}

- (void)clearFieldFocus {
    LOFormField *field = [self getFocusedField];
    [field releaseFieldFocus];
}

- (void)moveFocusToNextField {
    [self clearFieldFocus];
    LOFormField *field;
    for (NSInteger idx = _focusedFieldIdx + 1; idx < [_fields count]; idx++ ) {
        field = (LOFormField *)_fields[idx];
        if ([field takeFieldFocus]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
            [self selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
            _focusedFieldIdx = idx;
            break;
        }
    }
}

- (void)reset {
    for (LOFormField *field in _fields) {
        if (field.name) {
            id value = [_defaultValues objectForKey:field.name];
            field.value = (value == [NSNull null] ? nil : value);
        }
    }
}

- (BOOL)validate {
    BOOL ok = YES;
    for (NSInteger idx = 0; idx < [_fields count]; idx++) {
        LOFormField *field = (LOFormField *)_fields[idx];
        if (![field validate]) {
            // Scroll to the first invalid field.
            dispatch_async(dispatch_get_main_queue(), ^{
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
                [self selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
            });
            ok = NO;
            break;
        }
    }
    return ok;
}

- (BOOL)submit {
    BOOL ok = [self validate];
    if (ok) {
        if (_submitURL) {
            [self submitting:YES];
            [_httpClient submit:_method url:_submitURL data:self.inputValues]
            .then((id)^(SCHTTPClientResponse *response) {
                if ([self isSubmitErrorResponse:response]) {
                    [self submitError:response];
                }
                else {
                    [self submitOk:response];
                }
                [self submitting:NO];
                return nil;
            })
            .fail(^(id error) {
                [self submitRequestError:error];
                [self submitting:NO];
            });
        }
        else if (_submitURI) {
            [self submitting:YES];
            // Dispatch to queue to give UI chance to redraw.
            dispatch_async(dispatch_get_main_queue(), ^{
                // The submit URI is an internal URI which the form will post as a message.
                // The URI property is treated as a template into which the form's values can be inserted.
                NSDictionary *values = [self inputValues];
                NSString *message = [SCStringTemplate render:self->_submitURI context:values uriEncode:YES];
                [[SCAppContainer getAppContainer] postMessage:message sender:self];
                [self submitting:NO];
            });
        }
    }
    return ok;
}

- (void)submitting:(BOOL)submitting {
    [self beforeSubmit];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_loadingIndicator showFormLoading:submitting];
    });
    _isEnabled = !submitting;
}

- (void)beforeSubmit {
    if (_onBeforeSubmit) {
        _onBeforeSubmit(self, self.inputValues);
    }
}

- (BOOL)isSubmitErrorResponse:(SCHTTPClientResponse *)response {
    NSInteger statusCode = response.httpResponse.statusCode;
    return statusCode >= 400;
}

- (void)submitRequestError:(NSError *)error {
    if (_onSubmitRequestError) {
        _onSubmitRequestError(self, error);
    }
}

- (void)submitError:(SCHTTPClientResponse *)response {
    if (_onSubmitError) {
        _onSubmitError(self, [response parseData]);
    }
}

- (void)submitOk:(SCHTTPClientResponse *)response {
    if (_onSubmitOk) {
        _onSubmitOk(self, [response parseData]);
    }
}

- (void)notifyError:(NSString *)message {
    NSLog(@"%@", message );
}

- (void)notifyFormFieldResize:(LOFormField *)field {
    NSInteger idx = [_fields indexOfObject:field];
    if (idx != NSNotFound) {
        NSArray *paths = @[ [NSIndexPath indexPathForRow:idx inSection:0] ];
        [self reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (NSArray *)getFieldsInNameGroup:(NSString *)name {
    NSMutableArray *fields = [NSMutableArray new];
    for (LOFormField *field in _fields) {
        if ([field.name isEqualToString:name]) {
            [fields addObject:field];
        }
    }
    return fields;
}

#pragma mark - Overrides

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    // Notifications for when keyboard is shown or hidden.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
}

- (void)removeFromSuperview {
    [super removeFromSuperview];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private methods

- (void)keyboardDidShow:(NSNotification *)notification {
    _defaultInsets = self.contentInset;
    // Following taken from http://stackoverflow.com/a/5324303
    NSDictionary *keyboardInfo = [notification userInfo];
    NSValue *keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
    CGRect keyboardRect = [keyboardFrameBegin CGRectValue];
    // Following taken from http://stackoverflow.com/a/12125261
    self.contentInset = UIEdgeInsetsMake(_defaultInsets.top, _defaultInsets.left, keyboardRect.size.height, _defaultInsets.right);
    self.scrollIndicatorInsets = self.contentInset;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_focusedFieldIdx inSection:0];
    [self scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)keyboardDidHide:(NSNotification *)notification {
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = self->_defaultInsets;
        self.scrollIndicatorInsets = self->_defaultInsets;
    }];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return _fields[indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_fields count];
}

#pragma mark - UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    LOFormField *field = _fields[indexPath.row];
    return field.isSelectable;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self clearFieldFocus];
    _focusedFieldIdx = indexPath.row;
    LOFormField *field = _fields[_focusedFieldIdx];
    [field takeFieldFocus];
    [field selectField];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    LOFormField *field = _fields[_focusedFieldIdx];
    [field releaseFieldFocus];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    LOFormField *field = _fields[indexPath.row];
    return [field.height floatValue];
}

@end
