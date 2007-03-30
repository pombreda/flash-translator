#import <Foundation/Foundation.h>
#import "SWFParser.h"
#import "SWFWriter.h"
#import "SWFFont.h"
#import "SWFFreeType.h"
#import "SWFText.h"
#import "SWFShape.h"
#import "CSMemoryHandle.h"
#import "SSADocument.h"

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	if(argc!=4) return 1;
	
	NSMutableDictionary *fonts=[NSMutableDictionary dictionary];
	SWFParser *parser=[SWFParser parserForPath:[NSString stringWithUTF8String:argv[1]]];
	SWFWriter *writer=[SWFWriter writerForPath:[NSString stringWithUTF8String:argv[2]] parser:parser];
	SSADocument *ssa =[[SSADocument alloc] init];
	SWFFont *font = nil;
	
	[ssa loadFile:[NSString stringWithUTF8String:argv[3]] width:640 height:480];
	int scount = [ssa packetCount];
	
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
				SWFFont *font_=[[[SWFFont alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingData:contents] tag:[parser tag]] autorelease];
				
				[fonts setObject:font_ forKey:[NSNumber numberWithInt:[font_ identifier]]];
				[font_ write:writer];
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
				int frame = [parser frame];
				if(frame==5)
				{
					font=[[SWFFont alloc] initWithFilename:[@"~/mikachan-p.otf" stringByExpandingTildeInPath]
												   fontName:@"Mikachan-P" characterSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(32,127-32)]
												 identifier:0x1242];
					
					[font write:writer];
				} else if (frame >= (scount - 5)-2) {
					CSHandle *fh=[writer handle];
					[writer startTag:SWFRemoveObject2Tag];
					[fh writeUInt16LE:100]; // depth
					[writer endTag];
				} else if (frame > 5) {
					SubLine *sline = [ssa packet:frame-5];
					if (frame > 6) {
						CSHandle *fh=[writer handle];
						[writer startTag:SWFRemoveObject2Tag];
						[fh writeUInt16LE:100]; // depth
						[writer endTag];
					}
					
					SWFText *text=[[[SWFText alloc] initWithObjectIdentifier:0x1999 + frame - 5] autorelease];
					[text setRect:[parser rect]];
					
					[text addTextRecord:[SWFTextRecord recordWithText:[sline plaintext]
																 font:font height:500 position:SWFMakePoint(1000,1000) red:255 green:255 blue:255 alpha:255]];
					
					[text write:writer];
					
					CSHandle *fh=[writer handle];
					[writer startTag:SWFPlaceObject2Tag];
					[fh writeUInt8:2|4]; // add object, with matrix
					[fh writeUInt16LE:100]; // depth
					[fh writeUInt16LE:[text identifier]];
					SWFWriteMatrix(SWFRotationMatrix(0),fh);
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
