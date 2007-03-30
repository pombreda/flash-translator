#import "SWFText.h"
#import "SWFParser.h"
#import "SWFWriter.h"
#import "SWFFont.h"


@implementation SWFText

-(id)initWithObjectIdentifier:(int)identifier;
{
	if(self=[super init])
	{
		textrecords=[[NSMutableArray array] retain];

		ident=identifier;
		rect=SWFEmptyRect;
		mtx=SWFIdentityMatrix;
	}
	return self;
}

-(id)initWithParser:(SWFParser *)parser fonts:(NSDictionary *)fonts
{
	return [self initWithHandle:[parser handle] tag:[parser tag] fonts:fonts];
}

-(id)initWithHandle:(CSHandle *)fh tag:(int)tag fonts:(NSDictionary *)fonts;
{
	if(tag!=SWFDefineTextTag&&tag!=SWFDefineText2Tag)
	[NSException raise:@"SWFWrongTagException" format:@"The SWFText class can not parse this tag"];

	if(self=[super init])
	{
		textrecords=[[NSMutableArray array] retain];

		ident=[fh readUInt16LE];
		rect=SWFParseRect(fh);
		mtx=SWFParseMatrix(fh);

		int glyphbits=[fh readUInt8];
		int advbits=[fh readUInt8];

		SWFFont *font;
		int height=0;
		int r=0,g=0,b=0,a=255;
		SWFPoint pos=SWFMakePoint(0,0);

		for(;;)
		{
			int flags=[fh readUInt8];
			if(flags==0) break;

			if(flags&8) font=[fonts objectForKey:[NSNumber numberWithInt:[fh readUInt16LE]]];

			if(flags&4)
			{
				if(tag==SWFDefineTextTag)
				{
					r=[fh readUInt8];
					g=[fh readUInt8];
					b=[fh readUInt8];
				}
				else
				{
					r=[fh readUInt8];
					g=[fh readUInt8];
					b=[fh readUInt8];
					a=[fh readUInt8];
				}
			}

			if(flags&2) pos.x=[fh readUInt16LE];
			if(flags&1) pos.y=[fh readUInt16LE];
			if(flags&8) height=[fh readUInt16LE];

			uint8_t count=[fh readUInt8];
			NSMutableString *str=[NSMutableString string];
			int advances[count];

			for(int i=0;i<count;i++)
			{
				[str appendFormat:@"%C",[font decodeGlyph:[fh readBits:glyphbits]]];
				advances[i]=[fh readSignedBits:advbits];
			}

			SWFTextRecord *record=[SWFTextRecord recordWithText:str font:font height:height
			position:pos red:r green:g blue:b alpha:a advances:advances];
			[self addTextRecord:record];

			pos.x+=[record length];
		}
	}
	return self;
}

-(void)dealloc
{
	[textrecords release];
	[super dealloc];
}

-(void)write:(SWFWriter *)writer
{
	int tag;
	if([writer version]>=3) tag=SWFDefineText2Tag;
	else tag=SWFDefineTextTag;

	[writer startTag:tag];
	[self writeToHandle:[writer handle] tag:tag];
	[writer endTag];
}

-(void)writeToHandle:(CSHandle *)fh tag:(int)tag
{
	[fh writeUInt16LE:ident];
	SWFWriteRect(rect,fh);
	SWFWriteMatrix(mtx,fh);

	int glyphbits=16;
	int advbits=16;

	[fh writeUInt8:glyphbits];
	[fh writeUInt8:advbits];

	SWFFont *font=nil;
	int height=0;
	int r=-1,g=-1,b=-1,a=-1;
	SWFPoint pos=SWFMakePoint(0,0);

	NSEnumerator *enumerator=[textrecords objectEnumerator];
	SWFTextRecord *record;
	while(record=[enumerator nextObject])
	{
		int flags=0x80;

		if(font!=[record font]||height!=[record height])
		{
			flags|=8;
			font=[record font];
			height=[record height];
		}

		if(r!=[record red]||g!=[record green]||b!=[record blue]||a!=[record alpha])
		{
			flags|=4;
			r=[record red];
			g=[record green];
			b=[record blue];
			a=[record alpha];
		}

		SWFPoint newpos=[record position];
		if(pos.x!=newpos.x) flags|=2;
		if(pos.y!=newpos.y) flags|=1;
		pos=newpos;

		[fh writeUInt8:flags];

		if(flags&8) [fh writeUInt16LE:[font identifier]];

		if(flags&4)
		{
			if(tag==SWFDefineTextTag)
			{
				[fh writeUInt8:r];
				[fh writeUInt8:g];
				[fh writeUInt8:b];
			}
			else
			{
				[fh writeUInt8:r];
				[fh writeUInt8:g];
				[fh writeUInt8:b];
				[fh writeUInt8:a];
			}
		}

		if(flags&2) [fh writeUInt16LE:pos.x];
		if(flags&1) [fh writeUInt16LE:pos.y];
		if(flags&8) [fh writeUInt16LE:height];

		NSString *str=[record text];
		int *advances=[record advances];
		int count=[str length];

		[fh writeUInt8:count];

		for(int i=0;i<count;i++)
		{
			[fh writeBits:glyphbits value:[font encodeGlyph:[str characterAtIndex:i]]];
			[fh writeSignedBits:advbits value:advances[i]];
		}

		pos.x+=[record length];

		[fh flushWriteBits];
	}
	[fh writeUInt8:0];
}


-(int)identifier { return ident; }

-(SWFRect)rect { return rect; }
-(SWFMatrix)matrix { return mtx; }
-(void)setRect:(SWFRect)newrect { rect=newrect; }
-(void)setMatrix:(SWFMatrix)newmtx { mtx=newmtx; }

-(void)addTextRecord:(SWFTextRecord *)record
{
	[textrecords addObject:record];
}

-(NSArray *)textRecords { return textrecords; }

-(BOOL)hasUndefinedFonts
{
	NSEnumerator *enumerator=[textrecords objectEnumerator];
	SWFTextRecord *record;
	while(record=[enumerator nextObject]) if(![record font]) return YES;
	return NO;
}


@end




@implementation SWFTextRecord

+(SWFTextRecord *)recordWithText:(NSString *)txt font:(SWFFont *)fnt height:(int)h
position:(SWFPoint)pos red:(int)r green:(int)g blue:(int)b alpha:(int)a
{
	if ([fnt isMemberOfClass:[SWFText class]]) NSLog(@"!");

	return [self recordWithText:txt font:fnt height:h position:pos red:r green:g blue:b alpha:a advances:NULL];
}

+(SWFTextRecord *)recordWithText:(NSString *)txt font:(SWFFont *)fnt height:(int)h
position:(SWFPoint)pos red:(int)r green:(int)g blue:(int)b alpha:(int)a advances:(int *)adv
{
	SWFTextRecord *rec=[[[SWFTextRecord alloc] init] autorelease];
	if ([fnt isMemberOfClass:[SWFText class]]) NSLog(@"!");

	[rec setText:txt];
	[rec setFont:fnt];
	[rec setHeight:h];
	[rec setPosition:pos];
	[rec setRed:r];
	[rec setGreen:g];
	[rec setBlue:b];
	[rec setAlpha:a];
	[rec setAdvances:adv];
	return rec;
}

-(id)init
{
	if(self=[super init])
	{
		text=nil;
		font=nil;
		height=0;
		position=SWFZeroPoint;
		red=green=blue=0;
		alpha=255;
		advances=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(advances);
	[text release];
	[font release];
	[super dealloc];
}

-(SWFFont *)font { return font; }
-(NSString *)text { return text; }
-(int)height { return height; }
-(SWFPoint)position { return position; }
-(int)red { return red; }
-(int)green { return green; }
-(int)blue { return blue; }
-(int)alpha { return alpha; }
-(int *)advances
{
	if(advances) return advances;
	else return [font advancesForString:text height:height];
}

-(int)length
{
	int len=0;
	int *advptr=[self advances];
	int count=[text length];
	for(int i=0;i<count;i++) len+=advptr[i];
	return len;
}

-(void)setFont:(SWFFont *)newfont {	if ([font isMemberOfClass:[SWFText class]]) NSLog(@"!");	[font autorelease]; font=[newfont retain]; }
-(void)setText:(NSString *)newtext { [text autorelease]; text=[newtext retain]; }
-(void)setHeight:(int)h { height=h; }
-(void)setPosition:(SWFPoint)pos { position=pos; }
-(void)setRed:(int)r { red=r; }
-(void)setGreen:(int)g { green=g; }
-(void)setBlue:(int)b { blue=b; }
-(void)setAlpha:(int)a { alpha=a; }
-(void)setAdvances:(int *)adv
{
	free(advances);

	if(adv)
	{
		int size=[text length]*sizeof(int);
		advances=(int *)malloc(size);
		if(!advances) [NSException raise:@"SWFOutOfMemoryException" format:@"Out of memory."];

		memcpy(advances,adv,size);
	}
	else advances=NULL;
}

@end
