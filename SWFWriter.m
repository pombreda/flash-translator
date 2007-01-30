//
//  SWFWriter.m
//  FlashTranslator
//
//  Created by Dag Ågren on 2007-01-25.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SWFWriter.h"
#import "SWFParser.h"
#import "CSFileHandle.h"


@implementation SWFWriter

+(SWFWriter *)writerForPath:(NSString *)path version:(int)ver rect:(SWFRect)rect framesPerSecond:(int)fps
{
	CSFileHandle *handle=[CSFileHandle fileHandleForWritingAtPath:path];
	return [[[SWFWriter alloc] initWithHandle:handle version:ver rect:rect
	framesPerSecond:fps] autorelease];
}

+(SWFWriter *)writerForPath:(NSString *)path parser:(SWFParser *)parser
{
	CSFileHandle *handle=[CSFileHandle fileHandleForWritingAtPath:path];
	return [[[SWFWriter alloc] initWithHandle:handle version:[parser version]
	rect:[parser rect] framesPerSecond:[parser framesPerSecond]] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle version:(int)ver rect:(SWFRect)rect framesPerSecond:(int)fps
{
	if(self=[super init])
	{
		fh=[handle retain];
		version=ver;

		uint8_t magic[4]={'F','W','S',version};
		[fh writeBytes:4 fromBuffer:magic];
		[fh writeUInt32LE:0]; // total size, will be filled in later

		SWFWriteRect(rect,fh);
		[fh writeUInt16LE:fps];
		frameoffs=[fh offsetInFile];
		[fh writeUInt16LE:0]; // frames, will be filled in later

		frames=0;
		ended=NO;
	}
	return self;
}

-(void)dealloc
{
	if(!ended) [self startTag:SWFEndTag length:0];
	[fh release];
	[super dealloc];
}

-(void)startTag:(int)tag length:(int)len
{
	if(ended) [NSException raise:@"SWFWritingEndedException" format:@"Attempted to write to SWF file after writing an end tag"];

	if(tag==SWFShowFrameTag) frames++;
	else if(tag==SWFEndTag)
	{
		[fh writeUInt32LE:0];
		int size=[fh offsetInFile];
		[fh seekToFileOffset:4];
		[fh writeUInt32LE:size];
		[fh seekToFileOffset:frameoffs];
		[fh writeUInt16LE:frames];
		ended=YES;
		return;
	}

	if(len>=0x3f||
	tag==SWFDefineBitsLosslessTag||
    tag==SWFDefineBitsLossless2Tag||
    tag==SWFDefineBitsJPEGTag||
    tag==SWFDefineBitsJPEG2Tag||
    tag==SWFDefineBitsJPEG3Tag||
    tag==SWFSoundStreamBlockTag)
	{
		[fh writeUInt16LE:(tag<<6)|0x3f];
		[fh writeUInt32LE:len];
	}
	else
	{
		[fh writeUInt16LE:(tag<<6)|len];
	}

	lenoffs=0;
}

-(void)startTag:(int)tag
{
	[self startTag:tag length:0x7fffffff];
	lenoffs=[fh offsetInFile]-4;
}

-(void)endTag
{
	if(lenoffs)
	{
		off_t pos=[fh offsetInFile];
		[fh seekToFileOffset:lenoffs];
		[fh writeUInt32LE:pos-lenoffs-4];
		[fh seekToFileOffset:pos];
	}
}

-(void)writeTag:(int)tag contents:(NSData *)contents
{
	[self startTag:tag length:[contents length]];
	[fh writeData:contents];
	[self endTag];
}

-(int)version { return version; }

-(CSHandle *)handle { return fh; }

@end
