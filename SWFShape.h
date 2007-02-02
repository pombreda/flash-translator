#import <Foundation/Foundation.h>

#import "SWFGeometry.h"
#import "CSHandle.h"

@class SWFParser,SWFWriter;

@interface SWFShape:NSObject
{
	NSMutableArray *shaperecords;
}

-(id)init;
-(id)initWithHandle:(CSHandle *)fh;
-(void)dealloc;

-(void)moveTo:(SWFPoint)point;
-(void)lineTo:(SWFPoint)point;
-(void)curveTo:(SWFPoint)point control:(SWFPoint)control;

-(void)writeToHandle:(CSHandle *)fh;

@end

#define SWFShapeMoveRecord 0
#define SWFShapeLineRecord 1
#define SWFShapeCurveRecord 2

@interface SWFShapeRecord:NSObject
{
	int type;
	SWFPoint point,control;
}

-(id)initWithType:(int)t point:(SWFPoint)p;
-(id)initWithType:(int)t point:(SWFPoint)p control:(SWFPoint)c;

-(int)type;
-(SWFPoint)point;
-(SWFPoint)control;

@end
