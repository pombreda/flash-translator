#import "SWFFont.h"
#import "SWFParser.h"
#import "SWFWriter.h"
#import "SWFShape.h"

@implementation SWFFont

-(id)initWithName:(NSString *)fontname identifier:(int)identifier
{
	if(self=[super init])
	{
		ident=identifier;
		language=0;
		flags=4|8; // wide codes, wide offsets
		name=[fontname retain];
		large=NO;

		glyphs=[[NSMutableArray array] retain];
		glyphtable=[[NSMutableData data] retain];

		ascent=descent=leading=0;
		advtable=[[NSMutableData data] retain];
		recttable=nil;
		kerning=[[NSMutableDictionary dictionary] retain];
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

		ascent=descent=leading=0;
		advtable=nil;
		recttable=nil;
		kerning=[[NSMutableDictionary dictionary] retain];

		large=(tag==SWFDefineFont3Tag);

		// Note: does not properly handle unicode/shift_jis flags for < v6.0
		ident=[fh readUInt16LE];
		flags=[fh readUInt8];
		language=[fh readUInt8];

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

		if(flags&128)
		{
			ascent=[fh readInt16LE];
			descent=[fh readInt16LE];
			leading=[fh readInt16LE];

			advtable=[[NSMutableData dataWithLength:numglyphs*sizeof(int)] retain];
			int *advptr=(int *)[advtable mutableBytes];
			for(int i=0;i<numglyphs;i++) advptr[i]=[fh readInt16LE];

			recttable=[[NSMutableData dataWithLength:numglyphs*sizeof(SWFRect)] retain];
			SWFRect *rectptr=(SWFRect *)[recttable mutableBytes];
			for(int i=0;i<numglyphs;i++) rectptr[i]=SWFParseRect(fh);

			int numkern=[fh readUInt16LE];
			for(int i=0;i<numkern;i++)
			{
				int chr1,chr2;
				if(flags&4)
				{
					chr1=[self decodeGlyph:[fh readUInt16LE]];
					chr2=[self decodeGlyph:[fh readUInt16LE]];
				}
				else
				{
					chr1=[self decodeGlyph:[fh readUInt8]];
					chr2=[self decodeGlyph:[fh readUInt8]];
				}
				int kern=[fh readInt16LE];
				[self setKerning:kern forCharacter:chr1 andCharacter:chr2];
			}
		}
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


-(void)write:(SWFWriter *)writer { [self write:writer withLayoutInfo:[self hasLayoutInfo]]; }

-(void)write:(SWFWriter *)writer withLayoutInfo:(BOOL)writelayout
{
	if(large&&[writer version]<3) [NSException raise:@"SWFFontSavingException" format:@"Attempted to save large glyphs in a SWF file older than version 3."];

	int tag;
	if(large) tag=SWFDefineFont3Tag;
	else tag=SWFDefineFont2Tag;

	[writer startTag:tag];
	[self writeToHandle:[writer handle] withLayoutInfo:writelayout];
	[writer endTag];
}

-(void)writeToHandle:(CSHandle *)fh withLayoutInfo:(BOOL)writelayout
{
	if(writelayout&&![self hasLayoutInfo]) [NSException raise:@"SWFFontSavingException" format:@"Attempted to save layout info for a font that does not have it."];

	[fh writeUInt16LE:ident];

	int writeflags=flags;
	if(!writelayout) writeflags&=~128;
	[fh writeUInt8:writeflags];

	[fh writeUInt8:language];

	const char *namestr=[name UTF8String];
	int namelen=strlen(namestr);
	[fh writeUInt8:namelen];
	[fh writeBytes:namelen fromBuffer:namestr];

	int numglyphs=[glyphs count];
	[fh writeUInt16LE:numglyphs];

	// Save offset to start of table
	off_t baseoffs=[fh offsetInFile];

	// Write first glyph offset
	if(flags&8) [fh writeUInt32LE:4*numglyphs+4];
	else [fh writeUInt16LE:2*numglyphs+2];

	// Save position
	off_t nextoffs=[fh offsetInFile];

	// Write dummy values for the rest of the offsets
	for(int i=0;i<numglyphs;i++) if(flags&8) [fh writeUInt32LE:0];
	else [fh writeUInt16LE:0];

	// Write glyphs, seeking back to fill in the offset table after each
	for(int i=0;i<numglyphs;i++)
	{
		[[glyphs objectAtIndex:i] writeToHandle:fh];

		off_t curroffs=[fh offsetInFile];
		[fh seekToFileOffset:nextoffs];

		if(flags&8) [fh writeUInt32LE:curroffs-baseoffs];
		else [fh writeUInt16LE:curroffs-baseoffs];

		nextoffs=[fh offsetInFile];
		[fh seekToFileOffset:curroffs];
	}

	const unichar *glyphptr=(const unichar *)[glyphtable bytes];
	for(int i=0;i<numglyphs;i++)
	{
		if(flags&4) [fh writeUInt16LE:glyphptr[i]];
		else [fh writeUInt8:glyphptr[i]];
	}

	if(writelayout)
	{
		[fh writeInt16LE:ascent];
		[fh writeInt16LE:descent];
		[fh writeInt16LE:leading];

		const int *advptr=(const int *)[advtable bytes];
		for(int i=0;i<numglyphs;i++) [fh writeInt16LE:advptr[i]];

		const SWFRect *rectptr=(const SWFRect *)[recttable bytes];
		for(int i=0;i<numglyphs;i++) SWFWriteRect(rectptr[i],fh);

		int numkern=[kerning count];
		[fh writeUInt16BE:numkern];

		NSEnumerator *enumerator=[kerning keyEnumerator];
		NSNumber *key;
		while(key=[enumerator nextObject])
		{
			uint32_t keyval=[key unsignedLongValue];
			int chr1=keyval>>16;
			int chr2=keyval&0xffff;
			int kern=[[kerning objectForKey:key] intValue];
			if(flags&4)
			{
				[fh writeUInt16LE:chr1];
				[fh writeUInt16LE:chr2];
			}
			else
			{
				[fh writeUInt8:chr1];
				[fh writeUInt8:chr2];
			}
			[fh writeInt16LE:kern];
		}
	}
}


-(int)identifier { return ident; }
-(int)language { return language; }
-(NSString *)name { return name; }
-(BOOL)hasLargeGlyphs { return large; }
-(BOOL)hasLayoutInfo { return flags&128?YES:NO; }
-(int)ascent { return ascent; }
-(int)descent { return descent; }
-(int)leading { return leading; }

-(void)setLanguage:(int)lang { language=lang; }
-(void)setHasLargeGlyphs:(BOOL)largeglyphs { large=largeglyphs; }
-(void)setAscent:(int)asc { ascent=asc; }
-(void)setDescent:(int)desc { descent=desc; }
-(void)setLeading:(int)lead { leading=lead; }



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
	if(glyph<0||glyph>=[glyphs count]) return 0;
	
	return glyphptr[glyph];
}

-(int)encodeGlyph:(unichar)chr
{
	const unichar *glyphptr=(const unichar *)[glyphtable bytes];
	int count=[glyphs count];

	for(int i=0;i<count;i++) if(glyphptr[i]==chr) return i;
	return 0;
}

-(int *)advancesForString:(NSString *)string height:(int)height
{
	if(!advtable) [NSException raise:@"SWFNoDataException" format:@"Attempted to calculate advancess for a font that does not have that data."];

	int fontsize=large?20480:1024;
	const int *advptr=(const int *)[advtable bytes];

	int len=[string length];
	NSMutableData *data=[NSMutableData dataWithLength:len*sizeof(int)];
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

		advances[i]=(height*advance)/fontsize;
	}

	return advances;
}

@end
