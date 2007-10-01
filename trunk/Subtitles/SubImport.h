//
//  SubImport.h
//  SSARender2
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#ifndef __SUBIMPORT_H__
#define __SUBIMPORT_H__

#include <QuickTime/QuickTime.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import "SubContext.h"

@interface SubLine : NSObject
{
	@public
	NSString *line;
	unsigned begin_time, end_time;
}
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e;
@end

@interface SubSerializer : NSObject
{
	NSMutableArray *lines, *outpackets;
	BOOL finished, write_gap;
	unsigned last_time;
	SubLine *toReturn;
}
-(void)addLine:(SubLine *)sline;
-(void)setFinished:(BOOL)finished;
-(SubLine*)getSerializedPacket;
-(BOOL)isEmpty;
@end

extern NSString *LoadSSAFromPath(NSString *path, SubSerializer *ss);
extern void LoadSRTFromPath(NSString *path, SubSerializer *ss);

#endif
#endif