#import "SWFFont.h"

@interface SWFFont (FreeTypeParser)

-(id)initWithFontName:(NSString *)fontname characterSet:(NSIndexSet *)set identifier:(int)identifier;
-(id)initWithFilename:(NSString *)filename fontName:(NSString *)fontname
characterSet:(NSIndexSet *)set identifier:(int)identifier;

@end
