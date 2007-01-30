#import "SWFGeometry.h"


static inline int imax(int a,int b) { return a>b?a:b; }
static inline int imax4(int a,int b,int c,int d) { return imax(imax(a,b),imax(c,d)); }

SWFRect SWFParseRect(CSHandle *fh)
{
	int bits=[fh readBits:5];
	int xmin=[fh readSignedBits:bits];
	int xmax=[fh readSignedBits:bits];
	int ymin=[fh readSignedBits:bits];
	int ymax=[fh readSignedBits:bits];

	[fh flushReadBits];

	return SWFMakeRect(xmin,ymin,xmax-xmin,ymax-ymin);
}

void SWFWriteRect(SWFRect rect,CSHandle *fh)
{
	int xmin=rect.x;
	int xmax=rect.x+rect.width;
	int ymin=rect.y;
	int ymax=rect.y+rect.height;
	int bits=imax4(SWFCountSignedBits(xmin),SWFCountSignedBits(xmax),SWFCountSignedBits(ymin),SWFCountSignedBits(ymax));

	[fh writeSignedBits:5 value:bits];
	[fh writeSignedBits:bits value:xmin];
	[fh writeSignedBits:bits value:xmax];
	[fh writeSignedBits:bits value:ymin];
	[fh writeSignedBits:bits value:ymax];
	[fh flushWriteBits];
}

SWFMatrix SWFParseMatrix(CSHandle *fh)
{
	int a00=1<<16,a01=0,a02=0;
	int a10=0,a11=1<<16,a12=0;

	if([fh readBits:1])
	{
		int bits=[fh readBits:5];
		a00=[fh readSignedBits:bits];
		a11=[fh readSignedBits:bits];
	}

	if([fh readBits:1])
	{
		int bits=[fh readBits:5];
		a01=[fh readSignedBits:bits]; // may be wrong order
		a10=[fh readSignedBits:bits];
	}

	int bits=[fh readBits:5];
	a02=[fh readSignedBits:bits];
	a12=[fh readSignedBits:bits];

	[fh flushReadBits];

	return SWFMakeMatrix(a00,a01,a02,a10,a11,a12);
}

void SWFWriteMatrix(SWFMatrix mtx,CSHandle *fh)
{
	if(mtx.a00!=1<<16||mtx.a11!=1<<16)
	{
		int bits=imax(SWFCountSignedBits(mtx.a00),SWFCountSignedBits(mtx.a11));
		[fh writeBits:1 value:1];
		[fh writeBits:5 value:bits];
		[fh writeBits:bits value:mtx.a00];
		[fh writeBits:bits value:mtx.a11];
	}
	else [fh writeBits:1 value:0];

	if(mtx.a01!=0||mtx.a10!=0)
	{
		int bits=imax(SWFCountSignedBits(mtx.a01),SWFCountSignedBits(mtx.a10));
		[fh writeBits:1 value:1];
		[fh writeBits:5 value:bits];
		[fh writeBits:bits value:mtx.a01];
		[fh writeBits:bits value:mtx.a10];
	}
	else [fh writeBits:1 value:0];

	int bits=imax(SWFCountSignedBits(mtx.a02),SWFCountSignedBits(mtx.a12));
	[fh writeBits:5 value:bits];
	[fh writeBits:bits value:mtx.a02];
	[fh writeBits:bits value:mtx.a12];

	[fh flushWriteBits];
}

int SWFCountBits(uint32_t val)
{
	int res=0;
	if(val==0) return 0;
	if(val&0xFFFF0000) { res|=16; val>>=16; }
	if(val&0x0000FF00) { res|=8; val>>=8; }
	if(val&0x000000F0) { res|=4; val>>=4; }
	if(val&0x0000000C) { res|=2; val>>=2; }
	if(val&0x00000002) { res|=1; }
	return res+1;
}

int SWFCountSignedBits(int32_t val)
{
	if(val==0) return 0;
	else if(val<0) return SWFCountBits(~val)+1;
	else return SWFCountBits(val)+1;
}
