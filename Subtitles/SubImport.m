//
//  SubImport.m
//  SSARender2
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SubImport.h"
#import "SubParsing.h"
#import "SubUtilities.h"

//#define SS_DEBUG

static NSString *MatroskaPacketizeLine(NSDictionary *sub, int n)
{
	NSString *name = [sub objectForKey:@"Name"];
	if (!name) name = [sub objectForKey:@"Actor"];
	
	return [NSString stringWithFormat:@"%d,%d,%@,%@,%@,%@,%@,%@,%@\n",
		n+1,
		[[sub objectForKey:@"Layer"] intValue],
		[sub objectForKey:@"Style"],
		[sub objectForKey:@"Name"],
		[sub objectForKey:@"MarginL"],
		[sub objectForKey:@"MarginR"],
		[sub objectForKey:@"MarginV"],
		[sub objectForKey:@"Effect"],
		[sub objectForKey:@"Text"]];
}

static unsigned ParseSSATime(NSString *time)
{
	unsigned hour, minute, second, millisecond;
	
	sscanf([time UTF8String],"%u:%u:%u.%u",&hour,&minute,&second,&millisecond);
	
	return hour * 100 * 60 * 60 + minute * 100 * 60 + second * 100 + millisecond;
}

NSString *LoadSSAFromPath(NSString *path, SubSerializer *ss)
{
	NSString *nssSub = STStandardizeStringNewlines([NSString stringWithContentsOfFile:path]);
	
	if (!nssSub) return nil;
	
	size_t slen = [nssSub length], flen = sizeof(unichar) * (slen+1);
	unichar *subdata = (unichar*)malloc(flen);
	[nssSub getCharacters:subdata];
	
	if (subdata[slen-1] != '\n') subdata[slen++] = '\n'; // append newline if missing
	
	NSDictionary *headers;
	NSArray *subs;
	
	SubParseSSAFile(subdata, slen, &headers, NULL, &subs);
	free(subdata);
	
	int i, numlines = [subs count];
	
	for (i = 0; i < numlines; i++) {
		NSDictionary *sub = [subs objectAtIndex:i];
		SubLine *sl = [[SubLine alloc] initWithLine:MatroskaPacketizeLine(sub, i) 
											  start:ParseSSATime([sub objectForKey:@"Start"]) end:ParseSSATime([sub objectForKey:@"End"])];
		
		[ss addLine:sl];
		[sl autorelease];
	}
		
	return [nssSub substringToIndex:[nssSub rangeOfString:@"[Events]" options:NSLiteralSearch].location];
}

void LoadSRTFromPath(NSString *path, SubSerializer *ss)
{
	NSMutableString *srt = STStandardizeStringNewlines([NSString stringWithContentsOfFile:path]);
	if (!srt) return;
		
	if ([srt characterAtIndex:0] == 0xFEFF) [srt deleteCharactersInRange:NSMakeRange(0,1)];
	if ([srt characterAtIndex:[srt length]-1] != '\n') [srt appendFormat:@"%c",'\n'];
	
	NSScanner *sc = [NSScanner scannerWithString:srt];
	NSString *res=nil;
	[sc setCharactersToBeSkipped:nil];
	
	int h, m, s, ms;
	unsigned startTime=0, endTime=0;
	
	enum {
		INITIAL,
		TIMESTAMP,
		LINES
	} state = INITIAL;
	
	do {
		switch (state) {
			case INITIAL:
				if ([sc scanInt:NULL] == TRUE && [sc scanUpToString:@"\n" intoString:&res] == FALSE) {
					state = TIMESTAMP;
					[sc scanString:@"\n" intoString:nil];
				} else
					[sc setScanLocation:[sc scanLocation]+1];
				break;
			case TIMESTAMP:
				[sc scanInt:&h];  [sc scanString:@":" intoString:nil];
				[sc scanInt:&m];  [sc scanString:@":" intoString:nil];				
				[sc scanInt:&s];  [sc scanString:@"," intoString:nil];				
				[sc scanInt:&ms]; [sc scanString:@" --> " intoString:nil];
				startTime = ms + s*1000 + m*1000*60 + h*1000*60*60;
				[sc scanInt:&h];  [sc scanString:@":" intoString:nil];
				[sc scanInt:&m];  [sc scanString:@":" intoString:nil];				
				[sc scanInt:&s];  [sc scanString:@"," intoString:nil];				
				[sc scanInt:&ms]; [sc scanString:@"\n" intoString:nil];	
				endTime = ms + s*1000 + m*1000*60 + h*1000*60*60;
				state = LINES;
				break;
			case LINES:
				[sc scanUpToString:@"\n\n" intoString:&res];
				[sc scanString:@"\n\n" intoString:nil];
				SubLine *sl = [[SubLine alloc] initWithLine:res start:startTime end:endTime];
				[ss addLine:[sl autorelease]];
				state = INITIAL;
				break;
		};
	} while (![sc isAtEnd]);
}

#pragma mark Obj-C Classes

@implementation SubSerializer
-(id)init
{
	if (self = [super init]) {
		lines = [[NSMutableArray alloc] init];
		outpackets = [[NSMutableArray alloc] init];
		finished = NO;
		write_gap = NO;
		toReturn = nil;
		last_time = 0;
	}
	
	return self;
}

-(void)dealloc
{
	[outpackets release];
	[lines release];
	[super dealloc];
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
				if (accum) [accum appendString:slines[j]->line]; else accum = [[slines[j]->line mutableCopy] autorelease];
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
		last->end_time = times[num*2 - 3]; // end time of line before last
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
/*
-(SubLine*)getSerializedPacket
{
	if (!last_time) {
		SubLine *ret = [self _getSerializedPacket];
		if (ret) {
			last_time = ret->end_time;
			write_gap = YES;
		}
		return ret;
	}
	
restart:
	
	if (write_gap) {
		SubLine *next = [self _getSerializedPacket];
		SubLine *sl;

		if (!next) return nil;

		toReturn = [next retain];
		
		write_gap = NO;
		
		if (toReturn->begin_time > last_time) sl = [[SubLine alloc] initWithLine:@"\n" start:last_time end:toReturn->begin_time];
		else goto restart;
		
		return [sl autorelease];
	} else {
		SubLine *ret = toReturn;
		last_time = ret->end_time;
		write_gap = YES;
		
		toReturn = nil;
		return [ret autorelease];
	}
}
*/
-(void)setFinished:(BOOL)f
{
	finished = f;
}

-(BOOL)isEmpty
{
	return [lines count] == 0 && [outpackets count] == 0 && !toReturn;
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
		if ([l characterAtIndex:[l length]-1] != '\n') l = [l stringByAppendingString:@"\n"];
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
	return [NSString stringWithFormat:@"\"%@\", from %d s to %d s",line,begin_time,end_time];
}
@end