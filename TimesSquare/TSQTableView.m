//
//  TSQTableView.m
//  TimesSquare
//
//  Created by Will Lisac on 5/17/13.
//  Copyright (c) 2013 Square. All rights reserved.
//

#import "TSQTableView.h"

@implementation TSQTableView

-(BOOL)touchesShouldCancelInContentView:(UIView *)view
{
    BOOL cancelTouches = [super touchesShouldCancelInContentView:view];
    if (cancelTouches == NO) {
        cancelTouches = [view isKindOfClass:[UIButton class]];
    }
    return cancelTouches;
}

@end
