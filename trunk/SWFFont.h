#import <Foundation/Foundation.h>

#import "SWFGeometry.h"
#import "CSHandle.h"

@class SWFParser,SWFWriter,SWFShape;

@interface SWFFont:NSObject
{
	int ident,lang;
	NSString *name;

	NSMutableArray *glyphs;
	NSMutableData *glyphtable;
	NSMutableData *advtable;
	NSMutableDictionary *kerning;

	BOOL haslayout;
	int ascent,descent,leading_height;

//			signed short		f_font2_advance[f_font2_glyphs_count];
//			swf_rect		f_font2_bounds[f_font2_glyphs_count];
//			signed short		f_font2_kerning_count;
//			swf_kerning		f_font2_kerning[f_font2_kerning_count];

//	unichar *glyphtable;
}

-(id)initWithName:(NSString *)fontname identifier:(int)identifier;
-(id)initWithParser:(SWFParser *)parser;
-(id)initWithHandle:(CSHandle *)fh tag:(int)tag;
-(void)dealloc;

-(void)write:(SWFWriter *)writer;
-(void)writeToHandle:(CSHandle *)fh;

-(int)identifier;
-(NSString *)name;

-(void)addGlyph:(SWFShape *)glyph character:(unichar)chr advance:(int)adv;
-(void)setKerning:(int)kerndelta forCharacter:(unichar)chr1 andCharacter:(unichar)chr2;

-(unichar)decodeGlyph:(int)glyph;
-(int)encodeGlyph:(unichar)chr;
-(int *)advancesForString:(NSString *)string;

@end
