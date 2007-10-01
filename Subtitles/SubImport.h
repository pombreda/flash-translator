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

#ifdef __cplusplus
extern "C"
{
#endif

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
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

extern void SubLoadSSAFromPath(NSString *path, SubContext **meta, SubSerializer **lines, SubRenderer *renderer);
extern void SubLoadSRTFromPath(NSString *path, SubContext **meta, SubSerializer **lines, SubRenderer *renderer);

#endif
#endif