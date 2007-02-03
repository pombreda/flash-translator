#import <Foundation/Foundation.h>

#import "SWFGeometry.h"
#import "CSHandle.h"

@class SWFParser,SWFWriter,SWFShape;

@interface SWFFont:NSObject
{
	int ident,flags,language;
	NSString *name;
	BOOL large;

	NSMutableArray *glyphs;
	NSMutableData *glyphtable;

	int ascent,descent,leading;
	NSMutableData *advtable;
	NSMutableData *recttable;
	NSMutableDictionary *kerning;
}

-(id)initWithName:(NSString *)fontname identifier:(int)identifier;
-(id)initWithParser:(SWFParser *)parser;
-(id)initWithHandle:(CSHandle *)fh tag:(int)tag;
-(void)dealloc;

-(void)write:(SWFWriter *)writer;
-(void)write:(SWFWriter *)writer withLayoutInfo:(BOOL)writelayout;
-(void)writeToHandle:(CSHandle *)fh withLayoutInfo:(BOOL)writelayout;

-(int)identifier;
-(int)language;
-(NSString *)name;
-(BOOL)hasLargeGlyphs;
-(BOOL)hasLayoutInfo;
-(int)ascent;
-(int)descent;
-(int)leading;

-(void)setLanguage:(int)lang;
-(void)setHasLargeGlyphs:(BOOL)largeglyphs;
-(void)setAscent:(int)asc;
-(void)setDescent:(int)desc;
-(void)setLeading:(int)lead;

-(void)addGlyph:(SWFShape *)glyph character:(unichar)chr advance:(int)adv;
-(void)setKerning:(int)kerndelta forCharacter:(unichar)chr1 andCharacter:(unichar)chr2;

-(unichar)decodeGlyph:(int)glyph;
-(int)encodeGlyph:(unichar)chr;
-(int *)advancesForString:(NSString *)string height:(int)height;

@end
