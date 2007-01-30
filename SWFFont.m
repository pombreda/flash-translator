#import "SWFFont.h"
#import "SWFParser.h"

@implementation SWFFont

-(id)init
{
	if(self=[super init])
	{
		ident=0;
		flags=0;
		lang=0;
		name=nil;
		glyphs=nil;
		glyphtable=NULL;
	}

	return self;
}

-(id)initWithParser:(SWFParser *)parser
{
	return [self initWithHandle:[parser handle] tag:[parser tag]];
}

-(id)initWithHandle:(CSHandle *)fh tag:(int)tag
{
	if(tag!=SWFDefineFont2Tag&&tag!=SWFDefineFont3Tag)
	[NSException raise:@"SWFWrongTagException" format:@"The SWFFont class can not parse this tag"];

	if(self=[super init])
	{
		glyphs=[[NSMutableArray array] retain];
		glyphtable=NULL;

		ident=[fh readUInt16LE];
		flags=[fh readUInt8];
		lang=[fh readUInt8];

		int namelen=[fh readUInt8];
		char namebuf[namelen];
		[fh readBytes:namelen toBuffer:namebuf];
		name=[[NSString alloc] initWithBytes:namebuf length:namelen encoding:NSUTF8StringEncoding];

		int numglyphs=[fh readUInt16LE];

		if(flags&8)
		{
			[fh skipBytes:numglyphs*4];
			int mapoffs=[fh readUInt32LE];
			[fh skipBytes:mapoffs-numglyphs*4-4];
		}
		else
		{
			[fh skipBytes:numglyphs*2];
			int mapoffs=[fh readUInt16LE];
			[fh skipBytes:mapoffs-numglyphs*2-2];
		}

		// fill array with fake objects - should actually load them instead
		for(int i=0;i<numglyphs;i++) [glyphs addObject:[NSNull null]];

		glyphtable=(unichar *)malloc(numglyphs*sizeof(unichar));

		for(int i=0;i<numglyphs;i++)
		{
			if(flags&4) glyphtable[i]=[fh readUInt16LE];
			else glyphtable[i]=[fh readUInt8];
		}

		// should load the rest of the font info
	}

	return self;
}

-(void)dealloc
{
	free(glyphtable);
	[glyphs release];

	[super dealloc];
}

-(int)identifier { return ident; }

-(NSString *)name { return name; }

-(unichar)decodeGlyph:(int)glyph { return glyphtable[glyph]; }

-(int)encodeGlyph:(unichar)chr
{
	int count=[glyphs count];

	for(int i=0;i<count;i++) if(glyphtable[i]==chr) return i;
	return 0;
}

@end
