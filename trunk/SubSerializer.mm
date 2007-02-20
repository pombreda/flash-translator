/*
 *  SubImport.c
 *  Perian
 *
 *  Created by David Conrad on 10/12/06.
 *  Copyright 2006 Perian Project. All rights reserved.
 *
 */

// Imported from Perian; all code here was produced by me and gets a free LGPL exception! - astrange

#import "SubSerializer.h"
#import "Categories.h"

//#define SS_DEBUG

@implementation SubtitleSerializer
-(id)init
{
	if (self = [super init]) {
		lines = [[NSMutableArray alloc] init];
		outpackets = [[NSMutableArray alloc] init];
		finished = NO;
	}
	
	return self;
}

-(void)addLine:(SubLine *)sline
{
	if (sline->begin_time < sline->end_time)
	[lines addObject:sline];
}

static int cmp_line(id a, id b, void* unused)
{			
	SubLine *av = (SubLine*)a, *bv = (SubLine*)b;
	
	if (av->begin_time > bv->begin_time) return NSOrderedDescending;
	if (av->begin_time < bv->begin_time) return NSOrderedAscending;
	return NSOrderedSame;
}

static int cmp_uint(const void *a, const void *b)
{
	unsigned av = *(unsigned*)a, bv = *(unsigned*)b;
	
	if (av > bv) return 1;
	if (av < bv) return -1;
	return 0;
}

static bool isinrange(unsigned base, unsigned test_s, unsigned test_e)
{
	return (base >= test_s) && (base < test_e);
}

-(void)refill
{
	unsigned num = [lines count];
	unsigned min_allowed = finished ? 1 : 2;
	if (num < min_allowed) return;
	unsigned times[num*2], last_last_end = 0;
	SubLine *slines[num], *last=nil;
	bool last_has_invalid_end = false;
	
	[lines sortUsingFunction:cmp_line context:nil];
	[lines getObjects:slines];
#ifdef SS_DEBUG
	NSLog(@"pre - %@",lines);
#endif	
	//leave early if all subtitle lines overlap
	if (!finished) {
		bool all_overlap = true;
		int i;
		
		for (i=0;i < num-1;i++) {
			SubLine *c = slines[i], *n = slines[i+1];
			if (c->end_time <= n->begin_time) {all_overlap = false; break;}
		}
		
		if (all_overlap) return;
		
		for (i=0;i < num-1;i++) {
			if (isinrange(slines[num-1]->begin_time, slines[i]->begin_time, slines[i]->end_time)) {
				num = i + 1; break;
			}
		}
	}
		
	for (int i=0;i < num;i++) {
		times[i*2]   = slines[i]->begin_time;
		times[i*2+1] = slines[i]->end_time;
	}
		
	qsort(times, num*2, sizeof(unsigned), cmp_uint);
	
	for (int i=0;i < num*2; i++) {
		if (i > 0 && times[i-1] == times[i]) continue;
		NSMutableString *accum = nil;
		unsigned start = times[i], last_end = start, next_start=times[num*2-1], end = start;
		bool finishedOutput = false, is_last_line = false;
		
		// Add on packets until we find one that marks it ending (by starting later)
		// ...except if we know this is the last input packet from the stream, then we have to explicitly flush it
		if (finished && (times[i] == slines[num-1]->begin_time || times[i] == slines[num-1]->end_time)) finishedOutput = is_last_line = true;
			
		for (int j=0; j < num; j++) {
			if (isinrange(times[i], slines[j]->begin_time, slines[j]->end_time)) {
				
				// find the next line that starts after this one
				if (j != num-1) {
					unsigned ns = slines[j]->end_time;
					for (int h = j; h < num; h++) if (slines[h]->begin_time != slines[j]->begin_time) {ns = slines[h]->begin_time; break;}
					next_start = MIN(next_start, ns);
				} else next_start = slines[j]->end_time;
					
				last_end = MAX(slines[j]->end_time, last_end);
				if (accum) [accum appendString:slines[j]->line]; else accum = [slines[j]->line mutableCopy];
			} else if (j == num-1) finishedOutput = true;
		}
				
		if (accum && finishedOutput) {
			[accum deleteCharactersInRange:NSMakeRange([accum length] - 1, 1)]; // delete last newline
#ifdef SS_DEBUG
			NSLog(@"%d - %d %d",start,last_end,next_start);	
#endif
			if (last_has_invalid_end) {
				if (last_end < next_start) { 
					int j, set;
					for (j=i; j >= 0; j--) if (times[j] == last->begin_time) break;
					set = times[j+1];
					last->end_time = set;
				} else last->end_time = MIN(last_last_end,start); 
			}
			end = last_end;
			last_has_invalid_end = false;
			if (last_end > next_start && !is_last_line) last_has_invalid_end = true;
			SubLine *event = [[SubLine alloc] initWithLine:accum start:start end:end];
			
			[outpackets addObject:event];
			
			last_last_end = last_end;
			last = event;
		}
	}
	
	if (last_has_invalid_end) {
		last->end_time = slines[num-1]->begin_time;
	}
#ifdef SS_DEBUG
	NSLog(@"out - %@",outpackets);
#endif
	
	if (finished) [lines removeAllObjects];
	else {
		num = [lines count];
		for (int i = 0; i < num-1; i++) {
			if (isinrange(slines[num-1]->begin_time, slines[i]->begin_time, slines[i]->end_time)) break;
			[lines removeObject:slines[i]];
		}
	}
#ifdef SS_DEBUG
	NSLog(@"post - %@",lines);
#endif
}

-(SubLine*)getSerializedPacket
{
	if ([outpackets count] == 0)  {
		[self refill];
		if ([outpackets count] == 0) 
			return nil;
	}
	
	SubLine *sl = [outpackets objectAtIndex:0];
	[outpackets removeObjectAtIndex:0];
	
	[sl autorelease];
	return sl;
}

-(void)setFinished:(BOOL)f
{
	finished = f;
}

-(BOOL)isEmpty
{
	return [lines count] == 0 && [outpackets count] == 0;
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"i: %d o: %d finished inputting: %d",[lines count],[outpackets count],finished];
}
@end

@implementation SubLine
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e
{
	if (self = [super init]) {
		line = [l retain];
		begin_time = s;
		end_time = e;
	}
	
	return self;
}

-(void)dealloc
{
	[line release];
	[super dealloc];
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"\"%@\", %d -> %d",line,begin_time,end_time];
}
@end