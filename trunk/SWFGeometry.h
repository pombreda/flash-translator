#import "CSHandle.h"

typedef struct _SWFRect
{
	int x,y,width,height;
} SWFRect;

typedef struct _SWFMatrix
{
	int a00,a01,a02;
	int a10,a11,a12;
} SWFMatrix;

static inline SWFRect SWFMakeRect(int x,int y,int width,int height) { struct _SWFRect res={x,y,width,height}; return res; }
static inline SWFMatrix SWFMakeMatrix(int a00,int a01,int a02,int a10,int a11,int a12) { struct _SWFMatrix res={a00,a01,a02,a10,a11,a12}; return res; }
static inline SWFMatrix SWFTranslationMatrix(int x,int y) { return SWFMakeMatrix(1<<16,0,x,0,1<<16,y); }

#define SWFEmptyRect SWFMakeRect(0,0,0,0)
#define SWFIdentityMatrix SWFTranslationMatrix(0,0)

SWFRect SWFParseRect(CSHandle *fh);
void SWFWriteRect(SWFRect rect,CSHandle *fh);

SWFMatrix SWFParseMatrix(CSHandle *fh);
void SWFWriteMatrix(SWFMatrix mtx,CSHandle *fh);

int SWFCountBits(uint32_t val);
int SWFCountSignedBits(int32_t val);
