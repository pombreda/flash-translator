#import "SWFShape.h"
#import "SWFParser.h"
#import "SWFWriter.h"

@implementation SWFShape

-(id)init
{
	if(self=[super init])
	{
		shaperecords=[[NSMutableArray array] retain];
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)fh
{
	if(self=[super init])
	{
		shaperecords=[[NSMutableArray array] retain];

		int x=0,y=0;

		int fill_bits=[fh readBits:4];
		int line_bits=[fh readBits:4];
		if(fill_bits!=1&&line_bits!=0) [NSException raise:@"SWFShapeParsingException" format:@"Encountered shape with fill style bit count other than 1, or line style bit count other than 0."];

		for(;;)
		{
			if([fh readBits:1]) // edge
			{
				int type=[fh readBits:1];
				int bits=[fh readBits:4]+2;

				if(type==0)
				{
					int cx=x+[fh readSignedBits:bits];
					int cy=y+[fh readSignedBits:bits];
					x=cx+[fh readSignedBits:bits];
					y=cy+[fh readSignedBits:bits];
					[self curveTo:SWFMakePoint(x,y) control:SWFMakePoint(cx,cy)];
				}
				else
				{
					if([fh readBits:1]==1)
					{
						x+=[fh readSignedBits:bits];
						y+=[fh readSignedBits:bits];
					}
					else
					{
						if([fh readBits:1]==1) y+=[fh readSignedBits:bits];
						else x+=[fh readSignedBits:bits];
					}
					[self lineTo:SWFMakePoint(x,y)];
				}
			}
			else // setup
			{
				int flags=[fh readBits:5];
				if(flags==0) break;

				if(flags&16) [NSException raise:@"SWFShapeParsingException" format:@"Encountered shape with styles in a font definition."];
				if(flags&2) [NSException raise:@"SWFShapeParsingException" format:@"Encountered shape setting fill style 0 in a font definition."];

				if(flags&1)
				{
					int bits=[fh readBits:5];
					x=[fh readSignedBits:bits];
					y=[fh readSignedBits:bits];
					[self moveTo:SWFMakePoint(x,y)];
				}

				if(flags&4)
				{
					int fill=[fh readBits:fill_bits];
					if(fill!=1) [NSException raise:@"SWFShapeParsingException" format:@"Encountered shape setting fill style 1 to 0 in a font definition."];
				}

				//if(flags&2) // forbidden
				//{
				//	[fh readBits:fill_bits];
				//}

				//if(flags&8) // line_bits assumed to be 0
				//{
				//	[fh readBits:line_bits];
				//}
			}
		}
		[fh flushReadBits];
	}
	return self;
}

-(void)dealloc
{
	[shaperecords release];
	[super dealloc];
}




-(void)moveTo:(SWFPoint)point
{
	[shaperecords addObject:[[[SWFShapeRecord alloc] initWithType:SWFShapeMoveRecord point:point] autorelease]];
}

-(void)lineTo:(SWFPoint)point
{
	[shaperecords addObject:[[[SWFShapeRecord alloc] initWithType:SWFShapeLineRecord point:point] autorelease]];
}

-(void)curveTo:(SWFPoint)point control:(SWFPoint)control
{
	[shaperecords addObject:[[[SWFShapeRecord alloc] initWithType:SWFShapeCurveRecord point:point control:control] autorelease]];
}

-(void)writeToHandle:(CSHandle *)fh
{
	NSEnumerator *enumerator=[shaperecords objectEnumerator];
	SWFShapeRecord *record;
	while(record=[enumerator nextObject])
	{
		[fh writeUInt8:0x10];

		NSEnumerator *enumerator=[shaperecords objectEnumerator];
		SWFShapeRecord *record=[enumerator nextObject];

		if(record)
		{
			if([record type]!=SWFShapeMoveRecord)
			[NSException raise:@"SWFShapeSavingException" format:@"Shapes must start with a move record."];

			int bits;
			SWFPoint point,control;

			[fh writeBits:6 value:13];
			point=[record point];
			bits=SWFCountSignedBits2(point.x,point.y);
			[fh writeBits:5 value:bits];
			[fh writeSignedBits:bits value:point.x];
			[fh writeSignedBits:bits value:point.y];
			[fh writeBits:1 value:1];

			int x=point.x,y=point.y;

			while(record=[enumerator nextObject])
			{
				switch([record type])
				{
					case SWFShapeMoveRecord:
						[fh writeBits:6 value:1];

						point=[record point];
						bits=SWFCountSignedBits2(point.x,point.y);
						[fh writeBits:5 value:bits];
						[fh writeSignedBits:bits value:point.x];
						[fh writeSignedBits:bits value:point.y];
					break;

					case SWFShapeLineRecord:
						[fh writeBits:2 value:3];

						point=[record point];
						if(point.x==x)
						{
							bits=SWFCountSignedBits(point.x);
							[fh writeBits:4 value:bits-2];
							[fh writeBits:2 value:0];
							[fh writeSignedBits:bits value:point.x-x];
						}
						else if(point.y==y)
						{
							bits=SWFCountSignedBits(point.y);
							[fh writeBits:4 value:bits-2];
							[fh writeBits:2 value:1];
							[fh writeSignedBits:bits value:point.y-y];
						}
						else
						{
							bits=SWFCountSignedBits2(point.x,point.y);
							[fh writeBits:4 value:bits-2];
							[fh writeBits:1 value:1];
							[fh writeSignedBits:bits value:point.x-x];
							[fh writeSignedBits:bits value:point.y-y];
						}
					break;

					case SWFShapeCurveRecord:
						[fh writeBits:2 value:2];

						point=[record point];
						control=[record control];
						bits=SWFCountSignedBits4(point.x,point.y,control.x,control.y);
						[fh writeBits:4 value:bits-2];
						[fh writeSignedBits:bits value:control.x-x];
						[fh writeSignedBits:bits value:control.y-y];
						[fh writeSignedBits:bits value:point.x-control.x];
						[fh writeSignedBits:bits value:point.y-control.y];
					break;
				}

				x=point.x;
				y=point.y;
			}
		}

		[fh writeBits:6 value:0];
		[fh flushWriteBits];
	}
}

@end



@implementation SWFShapeRecord:NSObject

-(id)initWithType:(int)t point:(SWFPoint)p
{
	if(self=[super init])
	{
		type=t;
		point=p;
//		fill=f;
	}
	return self;
}

-(id)initWithType:(int)t point:(SWFPoint)p control:(SWFPoint)c
{
	if(self=[super init])
	{
		type=t;
		point=p;
		control=c;
//		fill=f;
	}
	return self;
}

-(int)type { return type; }
-(int)fill { return fill; }
-(SWFPoint)point { return point; }
-(SWFPoint)control { return control; }

@end
