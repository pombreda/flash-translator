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
					[self quadraticBezierTo:SWFMakePoint(x,y) control:SWFMakePoint(cx,cy)];
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
				//if(flags&2) [NSException raise:@"SWFShapeParsingException" format:@"Encountered shape setting fill style 0 in a font definition."];

				// Parse move
				if(flags&1)
				{
					int bits=[fh readBits:5];
					x=[fh readSignedBits:bits];
					y=[fh readSignedBits:bits];
					[self moveTo:SWFMakePoint(x,y)];
				}

				// Parse fill style 0
				if(flags&2) // forbidden
				{
					[fh readBits:fill_bits];
				}

				// Parse fill style 1
				if(flags&4)
				{
					/*int fill=*/[fh readBits:fill_bits];
					//if(fill!=1) [NSException raise:@"SWFShapeParsingException" format:@"Encountered shape setting fill style 1 to 0 in a font definition."];
				}

				// Parse line style
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

-(void)quadraticBezierTo:(SWFPoint)point control:(SWFPoint)control
{
	[shaperecords addObject:[[[SWFShapeRecord alloc] initWithType:SWFShapeCurveRecord point:point control:control] autorelease]];
}

-(void)cubicBezierTo:(SWFPoint)point firstControl:(SWFPoint)control1 secondControl:(SWFPoint)control2
{
	SWFPoint p0=[[shaperecords lastObject] point];
	SWFPoint p1=control1,p2=control2,p3=point; // just renaming for brevity

	SWFPoint t0=SWFPointOnLine(SWFPointOnLine(p0,p1,0.5),SWFPointOnLine(p1,p2,0.5),0.5);
	SWFPoint t1=SWFPointOnLine(SWFPointOnLine(p1,p2,0.5),SWFPointOnLine(p2,p3,0.5),0.5);

	SWFPoint c0=SWFPointOnLine(p0,p1,3.0/8.0);
	SWFPoint c1=SWFPointOnLine(t0,t1,1.0/8.0);
	SWFPoint c2=SWFPointOnLine(t1,t0,1.0/8.0);
	SWFPoint c3=SWFPointOnLine(p3,p2,3.0/8.0);

	SWFPoint a1=SWFPointOnLine(c0,c1,0.5);
	SWFPoint a2=SWFPointOnLine(t0,t1,0.5); // equivalent to SWFPointOnLine(c1,c2,0.5);
	SWFPoint a3=SWFPointOnLine(c2,c3,0.5);

	[self quadraticBezierTo:a1 control:c0];
	[self quadraticBezierTo:a2 control:c1];
	[self quadraticBezierTo:a3 control:c2];
	[self quadraticBezierTo:point control:c3];

//	[self quadraticBezierTo:SWFMakePoint((control1.x+control2.x)/2,(control1.y+control2.y)/2) control:control1];
//	[self quadraticBezierTo:point control:control2];
}

-(void)writeToHandle:(CSHandle *)fh
{
	// 1 fill bit, 0 style bits
//	[fh writeUInt8:0x10];
	[fh writeUInt8:0x10];

	NSEnumerator *enumerator=[shaperecords objectEnumerator];
	SWFShapeRecord *record=[enumerator nextObject];

	if(record)
	{
		if([record type]!=SWFShapeMoveRecord)
		[NSException raise:@"SWFShapeSavingException" format:@"Shapes must start with a move record."];

		int bits;
		SWFPoint point,control;

		[fh writeBits:6 value:13]; // setup record, defines line style, fill style 1 and move
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
					if(point.y==y)
					{
						bits=SWFCountSignedBits(point.x-x);
						[fh writeBits:4 value:bits-2];
						[fh writeBits:2 value:0];
						[fh writeSignedBits:bits value:point.x-x];
					}
					else if(point.x==x)
					{
						bits=SWFCountSignedBits(point.y-y);
						[fh writeBits:4 value:bits-2];
						[fh writeBits:2 value:1];
						[fh writeSignedBits:bits value:point.y-y];
					}
					else
					{
						bits=SWFCountSignedBits2(point.x-x,point.y-y);
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
					bits=SWFCountSignedBits4(control.x-x,control.y-y,point.x-control.x,point.y-control.y);
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

@end



@implementation SWFShapeRecord:NSObject

-(id)initWithType:(int)t point:(SWFPoint)p
{
	if(self=[super init])
	{
		type=t;
		point=p;
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
	}
	return self;
}

-(int)type { return type; }
-(SWFPoint)point { return point; }
-(SWFPoint)control { return control; }

@end
