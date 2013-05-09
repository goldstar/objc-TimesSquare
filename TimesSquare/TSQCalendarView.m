//
//  TSQCalendarState.m
//  TimesSquare
//
//  Created by Jim Puls on 11/14/12.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "TSQCalendarView.h"
#import "TSQCalendarMonthHeaderCell.h"
#import "TSQCalendarRowCell.h"

@interface TSQCalendarView () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TSQCalendarMonthHeaderCell *headerView; // nil unless pinsHeaderToTop == YES

@end


@implementation TSQCalendarView

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return nil;
    }

    [self _TSQCalendarView_commonInit];

    return self;
}

- (id)initWithFrame:(CGRect)frame;
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self _TSQCalendarView_commonInit];
    
    return self;
}

- (void)_TSQCalendarView_commonInit;
{
    _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    [self addSubview:_tableView];    
}

- (void)dealloc;
{
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
}

- (NSCalendar *)calendar;
{
    if (!_calendar) {
        self.calendar = [NSCalendar currentCalendar];
    }
    return _calendar;
}

- (Class)headerCellClass;
{
    if (!_headerCellClass) {
        self.headerCellClass = [TSQCalendarMonthHeaderCell class];
    }
    return _headerCellClass;
}

- (Class)rowCellClass;
{
    if (!_rowCellClass) {
        self.rowCellClass = [TSQCalendarRowCell class];
    }
    return _rowCellClass;
}

- (Class)cellClassForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (indexPath.row == 0 && !self.pinsHeaderToTop) {
        return [self headerCellClass];
    } else {
        return [self rowCellClass];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor;
{
    [super setBackgroundColor:backgroundColor];
    [self.tableView setBackgroundColor:backgroundColor];
}

- (void)setPinsHeaderToTop:(BOOL)pinsHeaderToTop;
{
    _pinsHeaderToTop = pinsHeaderToTop;
    [self setNeedsLayout];
}

- (void)setFirstDate:(NSDate *)firstDate;
{
    // clamp to the beginning of its month
    _firstDate = [self clampDate:firstDate toComponents:NSMonthCalendarUnit|NSYearCalendarUnit];
}

- (void)setLastDate:(NSDate *)lastDate;
{
    // clamp to the end of its month
    NSDate *firstOfMonth = [self clampDate:lastDate toComponents:NSMonthCalendarUnit|NSYearCalendarUnit];
    
    NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
    offsetComponents.month = 1;
    offsetComponents.day = -1;
    _lastDate = [self.calendar dateByAddingComponents:offsetComponents toDate:firstOfMonth options:0];
}

- (NSArray *)dateRangeBetweenDate:(NSDate*)date1 includingDate:(BOOL)include1 andDate:(NSDate*)date2 includingDate:(BOOL)include2
{
	if (!date1 && !date2)
		return @[];
	if (date1 && !date2)
		return @[date1];
	else if (date2 && !date1)
		return @[date2];
	
	NSMutableArray *range = [NSMutableArray array];
	
	NSDate *first = ([date1 compare:date2] == NSOrderedAscending) ? date1 : date2;
	NSDate *last = first == date1 ? date2 : date1;
	
	if (((first == date1) && include1) || ((first == date2) && include2)) {
		[range addObject:first];
	}
	
	NSDateComponents* oneDay = [[NSDateComponents alloc] init];
	[oneDay setDay:1];
	
	NSDate *tomorrow = first;
	while ([last compare:tomorrow] != NSOrderedSame)
	{
		tomorrow = [self.calendar dateByAddingComponents:oneDay toDate:tomorrow options:0];
		[range addObject:tomorrow];
	}
	[range removeLastObject];
	
	if (((last == date1) && include1) || ((last == date2) && include2)) {
		[range addObject:last];
	}
	
	return range;
}

- (void)setSelectedDates:(NSArray *)newSelectedDates;
{
    // clamp to beginning of each day
	NSMutableArray *dates = [NSMutableArray arrayWithCapacity:newSelectedDates.count];
	for (NSDate *date in newSelectedDates)
	{
		NSDate *startOfDay = [self clampDate:date toComponents:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit];
		if (![self.delegate respondsToSelector:@selector(calendarView:shouldSelectDate:)] || [self.delegate calendarView:self shouldSelectDate:startOfDay]) {
			[dates addObject:startOfDay];
		}
	}
	
	// if we don't have multiple selection, don't bother with range
	BOOL showsRange = self.showsRange && self.allowsMultipleSelection && (self.selectedDates.count > 1 || dates.count > 1);
	
	if (showsRange) {
		// if we're getting more than three dates, give up on being smart
		if (dates.count > 3) {
			dates = @[dates[0], dates[1]].mutableCopy;
		} else if (dates.count == 3 && self.selectedDates.count == 2) {
			NSMutableArray *tempDates = [dates mutableCopy];
			[tempDates removeObjectsInArray:self.selectedDates];
			if (tempDates.count != 1) {
				dates = @[dates[0], dates[1]].mutableCopy;
			} else {
				// replace the closest existing date with the new one
				NSDate *newDate = tempDates[0];
				CFTimeInterval interval1 = [newDate timeIntervalSinceDate:self.selectedDates[0]];
				CFTimeInterval interval2 = [newDate timeIntervalSinceDate:self.selectedDates[1]];
				NSDate *closestDate = fabsf(interval1) > fabsf(interval2) ? self.selectedDates[1] : self.selectedDates[0];
				[dates removeObject:closestDate];
			}
		}
	}
	
	// keep track of the dates we need to turn off, as well as on
	NSMutableArray *deselectingDates = [self.selectedDates mutableCopy];
	if (self.allowsMultipleSelection) {
		[deselectingDates removeObjectsInArray:dates];
	}
	
	if (!showsRange) {
		[dates removeObjectsInArray:self.selectedDates];
	}
	
	// trim to exactly one date if we don't allow multiple selection
	if (!self.allowsMultipleSelection ) {
		if (dates.count) {
			dates = [@[dates[0]] mutableCopy];
		}
	}
    
    if (!showsRange) {
		for (NSDate *date in deselectingDates) {
			[[self cellForRowAtDate:date] selectColumnForDate:date];
		}
	}
    
    if ([self.delegate respondsToSelector:@selector(calendarView:didDeselectDate:)]) {
        for (NSDate *date in deselectingDates) {
            [self.delegate calendarView:self didDeselectDate:date];
        }
    }
	
	// track selection area
	CGRect newlySelectedRect = CGRectNull;
	NSIndexPath *firstNewIndexPath = nil;
	
	for (NSDate *date in dates)
	{
		if (!showsRange) {
			[[self cellForRowAtDate:date] selectColumnForDate:date];
		}
		NSIndexPath *newIndexPath = [self indexPathForRowAtDate:date];
		CGRect newIndexPathRect = [self.tableView rectForRowAtIndexPath:newIndexPath];
		if (!firstNewIndexPath) {
			firstNewIndexPath = newIndexPath;
		}
		newlySelectedRect = CGRectUnion(newlySelectedRect, newIndexPathRect);
		
		if ([self.delegate respondsToSelector:@selector(calendarView:didSelectDate:)]) {
			[self.delegate calendarView:self didSelectDate:date];
		}
	}
	
	// scroll to reveal new selection area
	CGRect scrollBounds = self.tableView.bounds;
	
    if (firstNewIndexPath) {
        if (self.pagingEnabled) {
            CGRect sectionRect = [self.tableView rectForSection:firstNewIndexPath.section];
            [self.tableView setContentOffset:sectionRect.origin animated:YES];
        } else {
            if (CGRectGetMinY(scrollBounds) > CGRectGetMinY(newlySelectedRect)) {
                [self.tableView scrollToRowAtIndexPath:firstNewIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            } else if (CGRectGetMaxY(scrollBounds) < CGRectGetMaxY(newlySelectedRect)) {
                [self.tableView scrollToRowAtIndexPath:firstNewIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            }
        }
    }

	// set selection state to show the range
	if (showsRange) {
		NSArray *oldRange = [self dateRangeBetweenDate:self.selectedDates.count ? self.selectedDates[0] : nil includingDate:YES andDate:self.selectedDates.count > 1 ? self.selectedDates[1] : nil includingDate:YES];
		NSArray *newRange = [self dateRangeBetweenDate:dates.count ? dates[0] : nil includingDate:YES andDate:dates.count > 1 ? dates[1] : nil includingDate:YES];
		for (NSDate *date in oldRange) {
			[[self cellForRowAtDate:date] selectColumnForDate:date];
		}
		for (NSDate *date in newRange) {
			[[self cellForRowAtDate:date] selectColumnForDate:date];
		}
	}
	
	if (self.allowsMultipleSelection && !showsRange) {
		dates = newSelectedDates.mutableCopy;
	}

	_selectedDates = dates;
}

- (void)scrollToDate:(NSDate *)date animated:(BOOL)animated
{
  NSInteger section = [self sectionForDate:date];
  [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionTop animated:animated];
}

- (TSQCalendarMonthHeaderCell *)makeHeaderCellWithIdentifier:(NSString *)identifier;
{
    TSQCalendarMonthHeaderCell *cell = [[[self headerCellClass] alloc] initWithCalendar:self.calendar reuseIdentifier:identifier];
    cell.backgroundColor = self.backgroundColor;
    cell.calendarView = self;
    return cell;
}

#pragma mark Calendar calculations

- (NSDate *)firstOfMonthForSection:(NSInteger)section;
{
    NSDateComponents *offset = [NSDateComponents new];
    offset.month = section;
    return [self.calendar dateByAddingComponents:offset toDate:self.firstDate options:0];
}

- (TSQCalendarRowCell *)cellForRowAtDate:(NSDate *)date;
{
    return (TSQCalendarRowCell *)[self.tableView cellForRowAtIndexPath:[self indexPathForRowAtDate:date]];
}

- (NSInteger)sectionForDate:(NSDate *)date;
{
  return [self.calendar components:NSMonthCalendarUnit fromDate:self.firstDate toDate:date options:0].month;
}

- (NSIndexPath *)indexPathForRowAtDate:(NSDate *)date;
{
    if (!date) {
        return nil;
    }

    NSInteger section = [self sectionForDate:date];
    NSDate *firstOfMonth = [self firstOfMonthForSection:section];
    NSInteger firstWeek = [self.calendar components:NSWeekOfYearCalendarUnit fromDate:firstOfMonth].weekOfYear;
    NSInteger targetWeek = [self.calendar components:NSWeekOfYearCalendarUnit fromDate:date].weekOfYear;
    if (targetWeek < firstWeek) {
        targetWeek = [self.calendar maximumRangeOfUnit:NSWeekOfYearCalendarUnit].length;
    }
    return [NSIndexPath indexPathForRow:(self.pinsHeaderToTop ? 0 : 1) + targetWeek - firstWeek inSection:section];
}

#pragma mark UIView

- (void)layoutSubviews;
{
    if (self.pinsHeaderToTop) {
        if (!self.headerView) {
            self.headerView = [self makeHeaderCellWithIdentifier:nil];
            if (self.tableView.visibleCells.count > 0) {
                self.headerView.firstOfMonth = [self.tableView.visibleCells[0] firstOfMonth];
            } else {
                self.headerView.firstOfMonth = self.firstDate;
            }
            [self addSubview:self.headerView];
        }
        CGRect bounds = self.bounds;
        CGRect headerRect;
        CGRect tableRect;
        CGRectDivide(bounds, &headerRect, &tableRect, [[self headerCellClass] cellHeight], CGRectMinYEdge);
        self.headerView.frame = headerRect;
        self.tableView.frame = tableRect;
    } else {
        if (self.headerView) {
            [self.headerView removeFromSuperview];
            self.headerView = nil;
        }
        self.tableView.frame = self.bounds;
    }
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
    return 1 + [self.calendar components:NSMonthCalendarUnit fromDate:self.firstDate toDate:self.lastDate options:0].month;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    NSDate *firstOfMonth = [self firstOfMonthForSection:section];
    NSDateComponents *offset = [NSDateComponents new];
    offset.month = 1;
    offset.week = -1;
    offset.day = -1;
    NSDate *weekBeforeLastOfMonth = [self.calendar dateByAddingComponents:offset toDate:firstOfMonth options:0];

    NSInteger firstWeek = [self.calendar components:NSWeekOfYearCalendarUnit fromDate:firstOfMonth].weekOfYear;

    // -[NSDateComponents weekOfYear] doesn't explicitly specify what its valid range is. In the Gregorian case, it appears to be [1,52], which means the last day of December is probably going to be week 1 of next year. The same logic extends to other calendars.
    // To account for the wrap, we simply go a week earlier and add one to the difference.
    NSInteger nextToLastWeek = [self.calendar components:NSWeekOfYearCalendarUnit fromDate:weekBeforeLastOfMonth].weekOfYear;
    
    return (self.pinsHeaderToTop ? 2 : 3) + nextToLastWeek - firstWeek;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (indexPath.row == 0 && !self.pinsHeaderToTop) {
        // month header
        static NSString *identifier = @"header";
        TSQCalendarMonthHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [self makeHeaderCellWithIdentifier:identifier];
        }
        return cell;
    } else {
        static NSString *identifier = @"row";
        TSQCalendarRowCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[[self rowCellClass] alloc] initWithCalendar:self.calendar reuseIdentifier:identifier];
            cell.backgroundColor = self.backgroundColor;
            cell.calendarView = self;
        }
        return cell;
    }
}

#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    NSDate *firstOfMonth = [self firstOfMonthForSection:indexPath.section];
    [(TSQCalendarCell *)cell setFirstOfMonth:firstOfMonth];
    if (indexPath.row > 0 || self.pinsHeaderToTop) {
        NSInteger ordinalityOfFirstDay = [self.calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSWeekCalendarUnit forDate:firstOfMonth];
        NSDateComponents *dateComponents = [NSDateComponents new];
        dateComponents.day = 1 - ordinalityOfFirstDay;
        dateComponents.week = indexPath.row - (self.pinsHeaderToTop ? 0 : 1);
        [(TSQCalendarRowCell *)cell setBeginningDate:[self.calendar dateByAddingComponents:dateComponents toDate:firstOfMonth options:0]];
		if (!(self.showsRange && self.allowsMultipleSelection && self.selectedDates.count == 2)) {
			for (NSDate *date in self.selectedDates) {
				[(TSQCalendarRowCell *)cell selectColumnForDate:date];
			}
		} else {
			for (NSDate *date in [self dateRangeBetweenDate:self.selectedDates[0] includingDate:YES andDate:self.selectedDates[1] includingDate:YES]) {
				[(TSQCalendarRowCell *)cell selectColumnForDate:date];
			}
		}
        
        BOOL isBottomRow = (indexPath.row == [self tableView:tableView numberOfRowsInSection:indexPath.section] - (self.pinsHeaderToTop ? 0 : 1));
        [(TSQCalendarRowCell *)cell setBottomRow:isBottomRow];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    return [[self cellClassForRowAtIndexPath:indexPath] cellHeight];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;
{
    if (self.pagingEnabled) {
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:*targetContentOffset];
        // If the target offset is at the third row or later, target the next month; otherwise, target the beginning of this month.
        NSInteger section = indexPath.section;
        if (indexPath.row > 2) {
            section++;
        }
        CGRect sectionRect = [self.tableView rectForSection:section];
        *targetContentOffset = sectionRect.origin;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
{
    if (self.pinsHeaderToTop && self.tableView.visibleCells.count > 0) {
        TSQCalendarCell *cell = self.tableView.visibleCells[0];
        self.headerView.firstOfMonth = cell.firstOfMonth;
    }
}

- (NSDate *)clampDate:(NSDate *)date toComponents:(NSUInteger)unitFlags
{
    NSDateComponents *components = [self.calendar components:unitFlags fromDate:date];
    return [self.calendar dateFromComponents:components];
}

@end
