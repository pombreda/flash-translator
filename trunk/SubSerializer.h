/*
 *  SubImport.h
 *  Perian
 *
 *  Created by David Conrad on 10/12/06.
 *  Copyright 2006 Perian Project. All rights reserved.
 *
 */

#ifndef __SUBIMPORT_H__
#define __SUBIMPORT_H__

@interface SubLine : NSObject
{
	@public
	NSString *line;
	unsigned begin_time, end_time;
}
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e;
-(NSString*)plaintext;
@end

@interface SubtitleSerializer : NSObject
{
	NSMutableArray *lines, *outpackets;
	BOOL finished;
}
-(void)addLine:(SubLine *)sline;
-(void)setFinished:(BOOL)finished;
-(SubLine*)getSerializedPacket;
@end

#endif