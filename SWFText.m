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
		int move_x=0,move_y=0;

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

			if(flags&2) move_x=[fh readUInt16LE];
			if(flags&1) move_y=[fh readUInt16LE];
			if(flags&8) height=[fh readUInt16LE];

			uint8_t count=[fh readUInt8];
			NSMutableString *str=[NSMutableString string];
			int advances[count];

			for(int i=0;i<count;i++)
			{
				[str appendFormat:@"%C",[font decodeGlyph:[fh readBits:glyphbits]]];
				advances[i]=[fh readSignedBits:advbits];
			}
			[self addTextRecord:[SWFTextRecord recordWithText:str font:font height:height
			moveX:move_x moveY:move_y red:r green:g blue:b alpha:a advances:advances]];
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
//[fh writeUInt8:0];

	int glyphbits=16;
	int advbits=16;

	[fh writeUInt8:glyphbits];
	[fh writeUInt8:advbits];

	SWFFont *font=nil;
	int height=0;
	int r=-1,g=-1,b=-1,a=-1;
	int move_x=0,move_y=0;

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

		if(move_x!=[record moveX])
		{
			flags|=2;
			move_x=[record moveX];
		}

		if(move_y!=[record moveY])
		{
			flags|=1;
			move_y=[record moveY];
		}

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

		if(flags&2) [fh writeUInt16LE:move_x];
		if(flags&1) [fh writeUInt16LE:move_y];
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
	}
	[fh flushWriteBits];
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
moveX:(int)x moveY:(int)y red:(int)r green:(int)g blue:(int)b alpha:(int)a advances:(int *)adv
{
	SWFTextRecord *rec=[[[SWFTextRecord alloc] init] autorelease];
	[rec setText:txt];
	[rec setFont:fnt];
	[rec setHeight:h];
	[rec setMoveX:x];
	[rec setMoveY:y];
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
		move_x=move_y=0;
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
-(int)moveX { return move_x; }
-(int)moveY { return move_y; }
-(int)red { return red; }
-(int)green { return green; }
-(int)blue { return blue; }
-(int)alpha { return alpha; }
-(int *)advances { return advances; }

-(void)setFont:(SWFFont *)newfont { [font autorelease]; font=[newfont retain]; }
-(void)setText:(NSString *)newtext { [text autorelease]; text=[newtext retain]; }
-(void)setHeight:(int)h { height=h; }
-(void)setMoveX:(int)x { move_x=x; }
-(void)setMoveY:(int)y { move_y=y; }
-(void)setRed:(int)r { red=r; }
-(void)setGreen:(int)g { green=g; }
-(void)setBlue:(int)b { blue=b; }
-(void)setAlpha:(int)a { alpha=a; }
-(void)setAdvances:(int *)adv
{
	free(advances);

	int size=[text length]*sizeof(int);
	advances=(int *)malloc(size);
	if(!advances) [NSException raise:@"SWFOutOfMemoryException" format:@"Out of memory."];

	memcpy(advances,adv,size);
}

@end
