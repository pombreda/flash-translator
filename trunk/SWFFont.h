#import <Foundation/Foundation.h>

#import "SWFGeometry.h"
#import "CSHandle.h"

@class SWFParser;

@interface SWFFont:NSObject
{
	int ident,flags,lang;
	NSString *name;

	NSMutableArray *glyphs;
	unichar *glyphtable;
}

-(id)init;
-(id)initWithParser:(SWFParser *)parser;
-(id)initWithHandle:(CSHandle *)fh tag:(int)tag;
-(void)dealloc;

-(int)identifier;
-(NSString *)name;

-(unichar)decodeGlyph:(int)glyph;
-(int)encodeGlyph:(unichar)glyph;

@end
