#import <Foundation/Foundation.h>
#import "SWFParser.h"
#import "SWFWriter.h"
#import "SWFFont.h"
#import "SWFFreeType.h"
#import "SWFText.h"
#import "SWFShape.h"
#import "CSMemoryHandle.h"
#import "SSADocument.h"

void PrintEntry(SWFText *text,double appeartime,double disappeartime);

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	if(argc!=4) return 1;

	NSMutableDictionary *fonts=[NSMutableDictionary dictionary];
	SWFParser *parser=[SWFParser parserForPath:[NSString stringWithUTF8String:argv[1]]];
	SWFWriter *writer=[SWFWriter writerForPath:[NSString stringWithUTF8String:argv[2]] parser:parser];
	SSADocument *ssa =[[SSADocument alloc] init];
	
	[ssa loadFile:[NSString stringWithUTF8String:argv[3]] width:640 height:480];

	while([parser nextTag])
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
		switch([parser tag])
		{
			case SWFDefineFont2Tag:
			case SWFDefineFont3Tag:
			{
//				SWFFont *font=[[[SWFFont alloc] initWithParser:parser] autorelease];
				NSData *contents=[parser tagContents];
				SWFFont *font=[[[SWFFont alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingData:contents] tag:[parser tag]] autorelease];

				[fonts setObject:font forKey:[NSNumber numberWithInt:[font identifier]]];
				[font write:writer];
			}
			break;

			case SWFDefineTextTag:
			case SWFDefineText2Tag:
			{
				NSData *contents=[parser tagContents];

				SWFText *text=[[[SWFText alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingData:contents] tag:[parser tag] fonts:fonts] autorelease];

				if([text hasUndefinedFonts]) [writer writeTag:[parser tag] contents:contents];
				else [text write:writer];
			}
			break;

			case SWFShowFrameTag:
			{
				if([parser frame]==5)
				{
/*					SWFFont *font=[[[SWFFont alloc] initWithName:@"AmeoKun" identifier:0x1242] autorelease];

					SWFShape *a=[[[SWFShape alloc] init] autorelease];
					[a moveTo:SWFMakePoint(0,1024)];
					[a lineTo:SWFMakePoint(512,0)];
					[a lineTo:SWFMakePoint(1024,1024)];
					[a lineTo:SWFMakePoint(0,1024)];

					SWFShape *b=[[[SWFShape alloc] init] autorelease];
					[b moveTo:SWFMakePoint(0,0)];
					[b lineTo:SWFMakePoint(1024,0)];
					[b lineTo:SWFMakePoint(1024,1024)];
					[b lineTo:SWFMakePoint(0,1024)];
					[b lineTo:SWFMakePoint(0,0)];

					SWFShape *c=[[[SWFShape alloc] init] autorelease];
					[c moveTo:SWFMakePoint(512,0)];
					[c curveTo:SWFMakePoint(1024,512) control:SWFMakePoint(1024,0)];
					[c curveTo:SWFMakePoint(512,1024) control:SWFMakePoint(1024,1024)];
					[c curveTo:SWFMakePoint(0,512) control:SWFMakePoint(0,1024)];
					[c curveTo:SWFMakePoint(512,0) control:SWFMakePoint(0,0)];

					[font addGlyph:a character:'a' advance:1200];
					[font addGlyph:b character:'b' advance:1200];
					[font addGlyph:c character:'c' advance:1200];*/

					SWFFont *font=[[[SWFFont alloc] initWithFilename:[@"~/mikachan-p.otf" stringByExpandingTildeInPath]
					fontName:@"Mikachan-P" characterSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(32,127-32)]
					identifier:0x1242] autorelease];

					[font write:writer];

					SWFText *text=[[[SWFText alloc] initWithObjectIdentifier:0x1999] autorelease];
					[text setRect:[parser rect]];

					[text addTextRecord:[SWFTextRecord recordWithText:@"Ganbare, Mika-chan!"
					font:font height:500 position:SWFMakePoint(1000,1000) red:255 green:0 blue:0 alpha:255]];

					[text write:writer];

					CSHandle *fh=[writer handle];
					[writer startTag:SWFPlaceObject2Tag];
//					[fh writeUInt8:0x02]; // add object
//					[fh writeUInt16LE:100]; // depth
//					[fh writeUInt16LE:[text identifier]];
					[fh writeUInt8:2|4]; // add object, with matrix
					[fh writeUInt16LE:100]; // depth
					[fh writeUInt16LE:[text identifier]];
					SWFWriteMatrix(SWFRotationMatrix(30),fh);
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
