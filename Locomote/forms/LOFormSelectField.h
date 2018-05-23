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
//  Created by Julian Goacher on 27/02/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LOFormTextField.h"
#import "SCConfiguration.h"
#import "SCTableViewController.h"
#import "SCIOCTypeInspectable.h"

@class LOFormSelectField;

@interface LOFormSelectItemsViewController : SCTableViewController {
    UIBarButtonItem *_cancelButton;
}

@property (nonatomic, weak) LOFormSelectField *parentField;
@property (nonatomic, assign) NSInteger selectedIndex;

- (void)cancel;

@end

@interface LOFormSelectField : LOFormTextField <SCIOCContainerAware, SCIOCTypeInspectable> {
    id<SCConfiguration> _itemsListConfig;
    LOFormSelectItemsViewController *_itemsList;
    UINavigationController *_itemsListContainer;
}

@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) id nullItem;
@property (nonatomic, assign) NSDictionary *selectedItem;

@end
