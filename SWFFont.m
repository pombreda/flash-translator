#import "SWFFont.h"
#import "SWFParser.h"
#import "SWFWriter.h"

@implementation SWFFont

-(id)initWithName:(NSString *)fontname identifier:(int)identifier
{
	if(self=[super init])
	{
		ident=identifier;
		flags=0;
		lang=0;
		name=[fontname retain];

		glyphs=[[NSMutableArray array] retain];
		glyphtable=[[NSMutableData data] retain];
		advtable=[[NSMutableData data] retain];
		kerning=[[NSMutableDictionary dictionary] retain];

		haslayout=NO;
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
		glyphtable=nil;
		advtable=nil;

		ident=[fh readUInt16LE];
		flags=[fh readUInt8];
		lang=[fh readUInt8];

		int namelen=[fh readUInt8];
		char namebuf[namelen];
		[fh readBytes:namelen toBuffer:namebuf];
		name=[[NSString alloc] initWithBytes:namebuf length:namelen encoding:NSUTF8StringEncoding];

		int numglyphs=[fh readUInt16LE];
		int baseoffs=[fh offsetInFile];
		int offsets[numglyphs];
		int mapoffs;

		if(flags&8)
		{
			for(int i=0;i<numglyphs;i++) offsets[i]=[fh readUInt32LE]+baseoffs;
			mapoffs=[fh readUInt32LE]+baseoffs;
		}
		else
		{
			for(int i=0;i<numglyphs;i++) offsets[i]=[fh readUInt16LE]+baseoffs;
			mapoffs=[fh readUInt16LE]+baseoffs;
		}

		for(int i=0;i<numglyphs;i++)
		{
			[fh seekToFileOffset:offsets[i]];
			SWFShape *shape=[[SWFShape alloc] initWithHandle:fh];
			[glyphs addObject:shape];
			[shape release];
		}

		[fh seekToFileOffset:mapoffs];

		glyphtable=[[NSMutableData dataWithLength:numglyphs*sizeof(unichar)] retain];
		unichar *glyphptr=(unichar *)[glyphtable mutableBytes];

		for(int i=0;i<numglyphs;i++)
		{
			if(flags&4) glyphptr[i]=[fh readUInt16LE];
			else glyphptr[i]=[fh readUInt8];
		}

		haslayout=NO;
		// should load the rest of the font info
	}

	return self;
}

-(void)dealloc
{
	[name release];
	[glyphs release];
	[glyphtable release];
	[advtable release];
	[kerning release];

	[super dealloc];
}


-(void)write:(SWFWriter *)writer
{
/*	int tag;
	if([writer version]>=3) tag=SWFDefineText2Tag;
	else tag=SWFDefineTextTag;*/

	[writer startTag:SWFDefineFont2Tag];
	[self writeToHandle:[writer handle]];
	[writer endTag];
}

-(void)writeToHandle:(CSHandle *)fh
{
	[fh writeUInt16LE:ident];
}


-(int)identifier { return ident; }

-(NSString *)name { return name; }



-(void)addGlyph:(SWFShape *)glyph character:(unichar)chr advance:(int)adv
{
	if(!advtable) [NSException raise:@"SWFNoDataException" format:@"Attempted to modify a font without advance data."];

	[glyphs addObject:glyph];
	int count=[glyphs count];

	[glyphtable setLength:count*sizeof(unichar)];
	unichar *glyphptr=(unichar *)[glyphtable mutableBytes];
	glyphptr[count-1]=chr;

	[advtable setLength:count*sizeof(int)];
	int *advptr=(int *)[advtable mutableBytes];
	advptr[count-1]=adv;
}

-(void)setKerning:(int)kerndelta forCharacter:(unichar)chr1 andCharacter:(unichar)chr2;
{
	[kerning setObject:[NSNumber numberWithInt:kerndelta] forKey:[NSNumber numberWithUnsignedLong:(chr1<<16)+chr2]];
}



-(unichar)decodeGlyph:(int)glyph
{
	const unichar *glyphptr=(const unichar *)[glyphtable bytes];
	
	return glyphptr[glyph];
}

-(int)encodeGlyph:(unichar)chr
{
	const unichar *glyphptr=(const unichar *)[glyphtable bytes];
	int count=[glyphs count];

	for(int i=0;i<count;i++) if(glyphptr[i]==chr) return i;
	return 0;
}

-(int *)advancesForString:(NSString *)string
{
	if(!advtable) [NSException raise:@"SWFNoDataException" format:@"Attempted to calculate advancess for a font that does not have that data."];

	const int *advptr=(const int *)[advtable bytes];

	int len=[string length];
	NSMutableData *data=[NSMutableData data];
	int *advances=(int *)[data mutableBytes];

	for(int i=0;i<len;i++)
	{
		unichar curr=[string characterAtIndex:i];
		int advance=advptr[[self encodeGlyph:curr]];

		if(i!=len-1)
		{
			unichar next=[string characterAtIndex:i];
			NSNumber *kern=[kerning objectForKey:[NSNumber numberWithUnsignedLong:(curr<<16)+next]];
			if(kern) advance+=[kern intValue];
		}
		advances[i]=advance;
	}

	return advances;
}

@end
