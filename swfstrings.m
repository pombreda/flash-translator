#import <Foundation/Foundation.h>
#import "SWFParser.h"
#import "SWFFont.h"
#import "SWFText.h"

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	if(argc!=2) return 1;

	NSMutableDictionary *fonts=[NSMutableDictionary dictionary];
	SWFParser *parser=[SWFParser parserForPath:[NSString stringWithUTF8String:argv[1]]];

	for(;;)
	{
		switch([parser nextTag])
		{
			case SWFDefineFont2Tag:
			case SWFDefineFont3Tag:
			{
				SWFFont *font=[[[SWFFont alloc] initWithParser:parser] autorelease];
				[fonts setObject:font forKey:[NSNumber numberWithInt:[font identifier]]];
			}
			break;

			case SWFDefineTextTag:
			case SWFDefineText2Tag:
			{
				SWFText *text=[[[SWFText alloc] initWithParser:parser fonts:fonts] autorelease];
				NSEnumerator *enumerator=[[text textRecords] objectEnumerator];
				SWFTextRecord *record;
				while(record=[enumerator nextObject])
				printf("%s\n",[[record text] UTF8String]);
			}
			break;

			case SWFShowFrameTag:
//				NSLog(@"%d %g",[parser frame],[parser time]);
			break;

			case SWFEndTag: goto end;
		}
	}

	end:
	[pool release];
	return 0;
}
