#import <Foundation/Foundation.h>
#import "SWFParser.h"
#import "SWFFont.h"
#import "SWFText.h"

@interface SWFTextLine:NSObject
{
	@public
	SWFText *text;
	double appeartime, disappeartime;
	int depth;
}
@end

@implementation SWFTextLine
static NSString *SSATime(double t)
{
	unsigned ms = t * 100.;
	unsigned h, m, s;
	
	h = ms / (100*60*60);
	ms -= h * (100*60*60);
	m = ms / (100*60);
	ms -= m * (100*60);
	s = ms / 100;
	ms -= s * 100;
	
	return [NSString stringWithFormat:@"%0.1d:%0.2d:%0.2d.%0.2d",h,m,s,ms];
}

-(void)printEntry
{
	NSMutableString *str=nil;
	NSString *style=nil;
	
	NSEnumerator *enumerator=[[text textRecords] objectEnumerator];
	SWFTextRecord *record;
	
	while(record=[enumerator nextObject]) {
		NSString *style_ = [NSString stringWithFormat:@"S_%d",[[record font] identifier]];
		
		if (!style) {
			style = style_;
			str = [NSMutableString stringWithFormat:@"{\\fs%f}%@",[record height]/20.,[record text]];
			continue;
		}
		else if (![style isEqualToString:style_]) {
			[str appendFormat:@"{\\rS_%d\\fs%f}",[[record font] identifier],[record height]/20.];
		}
		
		[str appendFormat:@"\\N%@",[record text]];
	}

	printf("Dialogue: %d,%s,%s,%s,,0000,0000,0000,,%s\n",depth,[SSATime(appeartime) UTF8String],[SSATime(disappeartime) UTF8String],[style UTF8String],[str UTF8String]);
}
@end

static void AddEntry(SWFText *text,double appeartime,double disappeartime, NSMutableArray *lines, int depth)
{
	SWFTextLine *tl = [[[SWFTextLine alloc] init] autorelease];
	tl->text = text;
	tl->appeartime = appeartime;
	tl->disappeartime = disappeartime;
	[lines addObject:tl];
}

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	if(argc!=2) return 1;

	NSMutableDictionary *fonts=[NSMutableDictionary dictionary];
	NSMutableDictionary *texts=[NSMutableDictionary dictionary];
	NSMutableDictionary *depths=[NSMutableDictionary dictionary];
	NSMutableDictionary *appeartimes=[NSMutableDictionary dictionary];
	NSMutableArray *lines=[NSMutableArray array];
	
	SWFParser *parser=[SWFParser parserForPath:[NSString stringWithUTF8String:argv[1]]];
	SWFRect rect;	CSHandle *fh=[parser handle];

	while([parser nextTag])
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
		switch([parser tag])
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
				if(![text hasUndefinedFonts])
				[texts setObject:text forKey:[NSNumber numberWithInt:[text identifier]]];
			}
			break;

			case SWFPlaceObject2Tag:
			case SWFPlaceObject3Tag:
			{
				if([parser tag]==SWFPlaceObject3Tag) [fh readUInt8];

				int flags=[fh readUInt8];
				int depth=[fh readUInt16LE];

				if(flags&2) // adding new object
				{
					NSNumber *key=[depths objectForKey:[NSNumber numberWithInt:depth]];
					if(key)
					{
						SWFText *text=[texts objectForKey:key];
						NSNumber *appear=[appeartimes objectForKey:key];
						if(text&&appear) AddEntry(text,[appear doubleValue],[parser time], lines, depth);
						[depths removeObjectForKey:[NSNumber numberWithInt:depth]];
					}

					int ident=[fh readUInt16LE];
					[depths setObject:[NSNumber numberWithInt:ident] forKey:[NSNumber numberWithInt:depth]];
					[appeartimes setObject:[NSNumber numberWithDouble:[parser time]] forKey:[NSNumber numberWithInt:ident]];
				}
			}
			break;

			case SWFRemoveObject2Tag:
			{
				int depth=[fh readUInt16LE];
				NSNumber *key=[depths objectForKey:[NSNumber numberWithInt:depth]];

				SWFText *text=[texts objectForKey:key];
				NSNumber *appear=[appeartimes objectForKey:key];

				if(text&&appear) AddEntry(text,[appear doubleValue],[parser time], lines, depth);
				if(key) [depths removeObjectForKey:[NSNumber numberWithInt:depth]];
			}
			break;

			case SWFPlaceObjectTag:
			{
			NSLog(@"placeobject");
/*				int ident=[fh readUInt16BE];
				NSNumber *key=[NSNumber numberWithInt:ident];
				[appeartimes setObject:[NSNumber numberWithDouble:[parser time]] forKey:key];*/
			}
			break;

			case SWFRemoveObjectTag:
			{
			NSLog(@"removeobject");
/*				int ident=[fh readUInt16BE];
				NSNumber *key=[NSNumber numberWithInt:ident];

				SWFText *text=[texts objectForKey:key];
				NSNumber *appear=[appeartimes objectForKey:key];

				if(text&&appear) AddEntry(text,[appear doubleValue],[parser time]);
				if(appear) [appeartimes removeObjectForKey:key];*/
			}
			break;
		}
		[pool release];
	}

	NSEnumerator *enumerator=[depths objectEnumerator];
	NSNumber *key;
	while(key=[enumerator nextObject])
	{
		SWFText *text=[texts objectForKey:key];
		NSNumber *appear=[appeartimes objectForKey:key];

		if(text&&appear) AddEntry(text,[appear doubleValue],[parser time], lines, [key intValue]);
	}
	
	rect = [parser rect];
	
	printf("[Script Info]\nScriptType: v4.00+\nPlayResX: %f\nPlayResY: %f\n",rect.width / 20.,rect.height / 20.);
	printf("\n[V4+ Styles]\n");
	printf("Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n");
	SWFFont *font;
	enumerator = [fonts objectEnumerator];
	
	while (font = [enumerator nextObject]) {
		printf("Style: S_%d,%s,12,&H00000000,&H00000000,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,1,10,10,10,0\n", [font identifier], [[font name] UTF8String]);
	}
	
	SWFTextLine *tl;
	enumerator = [lines objectEnumerator];
	
	printf("\n[Events]\n");
	printf("Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n");
	
	while (tl = [enumerator nextObject]) {
		[tl printEntry];
	}
	
	[pool release];
	return 0;
}