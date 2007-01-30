#import <Foundation/Foundation.h>
#import "SWFParser.h"
#import "SWFWriter.h"
#import "SWFFont.h"
#import "SWFText.h"
#import "CSMemoryHandle.h"

void PrintEntry(SWFText *text,double appeartime,double disappeartime);

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	if(argc!=3) return 1;

	NSMutableDictionary *fonts=[NSMutableDictionary dictionary];
/*	NSMutableDictionary *texts=[NSMutableDictionary dictionary];
	NSMutableDictionary *depths=[NSMutableDictionary dictionary];
	NSMutableDictionary *appeartimes=[NSMutableDictionary dictionary];*/
	SWFParser *parser=[SWFParser parserForPath:[NSString stringWithUTF8String:argv[1]]];
	SWFWriter *writer=[SWFWriter writerForPath:[NSString stringWithUTF8String:argv[2]] parser:parser];
//	CSHandle *infh=[parser handle];
//	CSHandle *outfh=[writer handle];

	int lastfont;

	while([parser nextTag])
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
		switch([parser tag])
		{
			case SWFDefineFont2Tag:
			case SWFDefineFont3Tag:
			{
				NSData *contents=[parser tagContents];
				[writer writeTag:[parser tag] contents:contents];
				SWFFont *font=[[[SWFFont alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingData:contents] tag:[parser tag]] autorelease];
				[fonts setObject:font forKey:[NSNumber numberWithInt:[font identifier]]];
				lastfont=[font identifier];
			}
			break;

			case SWFDefineTextTag:
			case SWFDefineText2Tag:
			{
				NSData *contents=[parser tagContents];

				SWFText *text=[[[SWFText alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingData:contents] tag:[parser tag] fonts:fonts] autorelease];

				if([text hasUndefinedFonts]) [writer writeTag:[parser tag] contents:contents];
				else
				{
/*					CSMemoryHandle *outh=[CSMemoryHandle memoryHandleForWriting];
					[text writeToHandle:outh tag:[parser tag]];
					NSLog(@"\n%@\n%@",contents,[outh data]);
*///					exit(0);
					[text write:writer];
				}
			}
			break;

			case SWFShowFrameTag:
			{
				if([parser frame]==20)
				{
					SWFText *text=[[[SWFText alloc] initWithObjectIdentifier:0x1999] autorelease];
					[text setRect:SWFMakeRect(0,1000,2000,2000)];

					SWFFont *font=[fonts objectForKey:[NSNumber numberWithInt:lastfont]];
					NSString *str=[NSString stringWithFormat:@"%C%C%C%C",
					[font decodeGlyph:0],[font decodeGlyph:1],[font decodeGlyph:2],[font decodeGlyph:3]];
					int advances[]={500,500,500,500};

					[text addTextRecord:[SWFTextRecord recordWithText:str
					font:font height:500 moveX:1000 moveY:1000 red:255 green:0 blue:0 alpha:255
					advances:advances]];

					[text write:writer];

					CSHandle *fh=[writer handle];
					[writer startTag:SWFPlaceObject2Tag];
					[fh writeUInt8:0x02]; // add object
					[fh writeUInt16LE:100]; // depth
					[fh writeUInt16LE:[text identifier]];
					[writer endTag];
				}
				else if([parser frame]==60)
				{
					CSHandle *fh=[writer handle];
					[writer startTag:SWFRemoveObject2Tag];
					[fh writeUInt16LE:100]; // depth
					[writer endTag];
				}

				[writer startTag:SWFShowFrameTag length:0];
				[writer endTag];
			}
			break;

			default:
			{
				NSData *contents=[parser tagContents];
				[writer writeTag:[parser tag] contents:contents];
			}
			break;
		}
		[pool release];
	}

	[pool release];
	return 0;
}
