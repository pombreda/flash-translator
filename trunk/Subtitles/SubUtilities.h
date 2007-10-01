//
//  SubUtilities.h
//  SSARender2
//
//  Created by Alexander Strange on 7/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
	
extern NSArray *STSplitStringIgnoringWhitespace(NSString *str, NSString *split);
extern NSArray *STSplitStringWithCount(NSString *str, NSString *split, size_t count);
extern NSMutableString *STStandardizeStringNewlines(NSString *str);
extern void STSortMutableArrayStably(NSMutableArray *array, int (*compare)(const void *, const void *));
