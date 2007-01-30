#import <Foundation/Foundation.h>

#import "SWFGeometry.h"
#import "CSHandle.h"

@class SWFParser;

@interface SWFWriter:NSObject
{
	CSHandle *fh;
	int version;

	off_t frameoffs,lenoffs;
	int frames;
	BOOL ended;
}

+(SWFWriter *)writerForPath:(NSString *)path version:(int)ver rect:(SWFRect)rect framesPerSecond:(int)fps;
+(SWFWriter *)writerForPath:(NSString *)path parser:(SWFParser *)parser;

-(id)initWithHandle:(CSHandle *)handle version:(int)ver rect:(SWFRect)rect framesPerSecond:(int)fps;
-(void)dealloc;

-(void)startTag:(int)tag length:(int)len;
-(void)startTag:(int)tag;
-(void)endTag;

-(void)writeTag:(int)tag contents:(NSData *)contents;

-(int)version;
-(CSHandle *)handle;

@end
