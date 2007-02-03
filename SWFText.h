#import <Foundation/Foundation.h>

#import "SWFGeometry.h"
#import "CSHandle.h"

@class SWFParser,SWFWriter,SWFTextRecord,SWFFont;

@interface SWFText:NSObject
{
	NSMutableArray *textrecords;

	int ident;
	SWFRect rect;
	SWFMatrix mtx;
}

-(id)initWithObjectIdentifier:(int)identifier;
-(id)initWithParser:(SWFParser *)parser fonts:(NSDictionary *)fonts;
-(id)initWithHandle:(CSHandle *)fh tag:(int)tag fonts:(NSDictionary *)fonts;
-(void)dealloc;

-(void)write:(SWFWriter *)writer;
-(void)writeToHandle:(CSHandle *)fh tag:(int)tag;

-(int)identifier;

-(SWFRect)rect;
-(SWFMatrix)matrix;
-(void)setRect:(SWFRect)newrect;
-(void)setMatrix:(SWFMatrix)newmtx;

-(void)addTextRecord:(SWFTextRecord *)record;
-(NSArray *)textRecords;

-(BOOL)hasUndefinedFonts;

@end

@interface SWFTextRecord:NSObject
{
	NSString *text;
	SWFFont *font;
	int height;
	SWFPoint position;
	int red,green,blue,alpha;
	int *advances;
}

+(SWFTextRecord *)recordWithText:(NSString *)txt font:(SWFFont *)fnt height:(int)h
position:(SWFPoint)pos red:(int)r green:(int)g blue:(int)b alpha:(int)a;
+(SWFTextRecord *)recordWithText:(NSString *)txt font:(SWFFont *)fnt height:(int)h
position:(SWFPoint)pos red:(int)r green:(int)g blue:(int)b alpha:(int)a advances:(int *)adv;

-(id)init;
-(void)dealloc;

-(NSString *)text;
-(SWFFont *)font;
-(int)height;
-(SWFPoint)position;
-(int)red;
-(int)green;
-(int)blue;
-(int)alpha;
-(int *)advances;

-(int)length;

-(void)setText:(NSString *)newtext;
-(void)setFont:(SWFFont *)newfont;
-(void)setHeight:(int)h;
-(void)setPosition:(SWFPoint)pos;
-(void)setRed:(int)r;
-(void)setGreen:(int)g;
-(void)setBlue:(int)b;
-(void)setAlpha:(int)a;
-(void)setAdvances:(int *)adv;

@end
