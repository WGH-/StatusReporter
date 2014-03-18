/*
   StatusReporter
   Copyright (C) Wormbo 
   Copyright (C) 2012 Maxim "WGH"
   
   This program is free software; you can redistribute and/or modify 
   it under the terms of the Open Unreal Mod License version 1.1.
*/
/******************************************************************************
SHA1 hash implementation for UnrealScript by Wormbo.
Feel free to modify and optimize for your needs.
******************************************************************************/
 
class SHA1Hash extends Object;
 
 
struct SHA1Result { var int A,B,C,D,E; };
 
/** @ignore */
var private SHA1Result StaticHashValue;
/** @ignore */
var private array<byte> StaticData;
 
 
//=============================================================================
// Instant hash functions - probably not suitable for large input data
//=============================================================================
 
final function SHA1Result GetStringHash(string In)
{
  local int StrLen, i;
 
  StrLen = Len(In);
  StaticData.Length = StrLen;
  for (i = 0; i < StrLen; i++) {
    StaticData[i] = Asc(Mid(In, i, 1));
  }
  StaticProcessChunks();
  return StaticHashValue;
}
 
final function string GetStringHashString(string In)
{
  local int StrLen, i;
 
  StrLen = Len(In);
  StaticData.Length = StrLen;
  for (i = 0; i < StrLen; i++) {
    StaticData[i] = Asc(Mid(In, i, 1));
  }
  StaticProcessChunks();
  return BigEndianToHex(StaticHashValue.A)
      $ BigEndianToHex(StaticHashValue.B)
      $ BigEndianToHex(StaticHashValue.C)
      $ BigEndianToHex(StaticHashValue.D)
      $ BigEndianToHex(StaticHashValue.E);
}
 
final function SHA1Result GetArrayHash(array<byte> In)
{
  StaticData = In;
  StaticProcessChunks();
  return StaticHashValue;
}
 
final function string GetArrayHashString(array<byte> In)
{
  StaticData = In;
  StaticProcessChunks();
  return BigEndianToHex(StaticHashValue.A)
      $ BigEndianToHex(StaticHashValue.B)
      $ BigEndianToHex(StaticHashValue.C)
      $ BigEndianToHex(StaticHashValue.D)
      $ BigEndianToHex(StaticHashValue.E);
}
 
final function string GetHashString(SHA1Result Hash)
{
  return BigEndianToHex(Hash.A) $ BigEndianToHex(Hash.B)
      $ BigEndianToHex(Hash.C) $ BigEndianToHex(Hash.D) $ BigEndianToHex(Hash.E);
}
 
// Shambler: Limited use, this appends to rather than returning an array because I had special use for it
final function GetHashBytes(out array<byte> HashBytes, SHA1Result Hash)
{
	local int i;
 
	i = HashBytes.Length;
	HashBytes.Length = HashBytes.Length + 20;
 
	HashBytes[i] =		(Hash.A >> 24)	& 0xff;
	HashBytes[i+1] =	(Hash.A >> 16)	& 0xff;
	HashBytes[i+2] =	(Hash.A >> 8)	& 0xff;
	HashBytes[i+3] =	Hash.A		& 0xff;
	HashBytes[i+4] =	(Hash.B >> 24)	& 0xff;
	HashBytes[i+5] =	(Hash.B >> 16)	& 0xff;
	HashBytes[i+6] =	(Hash.B >> 8)	& 0xff;
	HashBytes[i+7] =	Hash.B		& 0xff;
	HashBytes[i+8] =	(Hash.C >> 24)	& 0xff;
	HashBytes[i+9] =	(Hash.C >> 16)	& 0xff;
	HashBytes[i+10] =	(Hash.C >> 8)	& 0xff;
	HashBytes[i+11] =	Hash.C		& 0xff;
	HashBytes[i+12] =	(Hash.D >> 24)	& 0xff;
	HashBytes[i+13] =	(Hash.D >> 16)	& 0xff;
	HashBytes[i+14] =	(Hash.D >> 8)	& 0xff;
	HashBytes[i+15] =	Hash.D		& 0xff;
	HashBytes[i+16] =	(Hash.E >> 24)	& 0xff;
	HashBytes[i+17] =	(Hash.E >> 16)	& 0xff;
	HashBytes[i+18] =	(Hash.E >> 8)	& 0xff;
	HashBytes[i+19] =	Hash.E		& 0xff;
}
 
 
//=============================================================================
// Internal stuff for instant hashing functions
//=============================================================================
 
final function string BigEndianToHex(int i)
{
  const hex = "0123456789abcdef";
 
  return Mid(hex, i >> 28 & 0xf, 1) $ Mid(hex, i >> 24 & 0xf, 1)
      $ Mid(hex, i >> 20 & 0xf, 1) $ Mid(hex, i >> 16 & 0xf, 1)
      $ Mid(hex, i >> 12 & 0xf, 1) $ Mid(hex, i >> 8 & 0xf, 1)
      $ Mid(hex, i >> 4 & 0xf, 1) $ Mid(hex, i & 0xf, 1);
}
 
private final function StaticProcessChunks()
{
  local int i, chunk, temp;
  local int A, B, C, D, E;
  local array<int> w;
 
  i = StaticData.Length;
  if (i % 64 < 56)
    StaticData.Length = StaticData.Length + 64 - i % 64;
  else
    StaticData.Length = StaticData.Length + 128 - i % 64;
  StaticData[i] = 0x80;
  StaticData[StaticData.Length - 5] = (i >>> 29);
  StaticData[StaticData.Length - 4] = (i >>> 21);
  StaticData[StaticData.Length - 3] = (i >>> 13);
  StaticData[StaticData.Length - 2] = (i >>>  5);
  StaticData[StaticData.Length - 1] = (i <<   3);
 
  StaticHashValue.A = 0x67452301;
  StaticHashValue.B = 0xEFCDAB89;
  StaticHashValue.C = 0x98BADCFE;
  StaticHashValue.D = 0x10325476;
  StaticHashValue.E = 0xC3D2E1F0;
 
  while (chunk * 64 < StaticData.Length) {
    w.Length = 80;
    for (i = 0; i < 16; i++) {
      w[i] = (StaticData[chunk * 64 + i * 4] << 24)
          | (StaticData[chunk * 64 + i * 4 + 1] << 16)
          | (StaticData[chunk * 64 + i * 4 + 2] << 8)
          | StaticData[chunk * 64 + i * 4 + 3];
    }
    for (i = 16; i < 80; i++) {
      temp = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
      w[i] = (temp << 1) | (temp >>> 31);
    }
 
    // initialize hash value for this chunk
    A = StaticHashValue.A;
    B = StaticHashValue.B;
    C = StaticHashValue.C;
    D = StaticHashValue.D;
    E = StaticHashValue.E;
 
    // round 1
    E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[ 0] + 0x5A827999;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[ 1] + 0x5A827999;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[ 2] + 0x5A827999;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[ 3] + 0x5A827999;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[ 4] + 0x5A827999;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[ 5] + 0x5A827999;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[ 6] + 0x5A827999;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[ 7] + 0x5A827999;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[ 8] + 0x5A827999;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[ 9] + 0x5A827999;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[10] + 0x5A827999;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[11] + 0x5A827999;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[12] + 0x5A827999;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[13] + 0x5A827999;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[14] + 0x5A827999;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[15] + 0x5A827999;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[16] + 0x5A827999;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[17] + 0x5A827999;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[18] + 0x5A827999;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[19] + 0x5A827999;    C = (C << 30) | (C >>> -30);
 
    // round 2
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[20] + 0x6ED9EBA1;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[21] + 0x6ED9EBA1;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[22] + 0x6ED9EBA1;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[23] + 0x6ED9EBA1;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[24] + 0x6ED9EBA1;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[25] + 0x6ED9EBA1;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[26] + 0x6ED9EBA1;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[27] + 0x6ED9EBA1;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[28] + 0x6ED9EBA1;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[29] + 0x6ED9EBA1;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[30] + 0x6ED9EBA1;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[31] + 0x6ED9EBA1;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[32] + 0x6ED9EBA1;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[33] + 0x6ED9EBA1;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[34] + 0x6ED9EBA1;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[35] + 0x6ED9EBA1;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[36] + 0x6ED9EBA1;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[37] + 0x6ED9EBA1;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[38] + 0x6ED9EBA1;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[39] + 0x6ED9EBA1;    C = (C << 30) | (C >>> -30);
 
    // round 3
    E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[40] + 0x8F1BBCDC;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[41] + 0x8F1BBCDC;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[42] + 0x8F1BBCDC;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[43] + 0x8F1BBCDC;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[44] + 0x8F1BBCDC;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[45] + 0x8F1BBCDC;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[46] + 0x8F1BBCDC;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[47] + 0x8F1BBCDC;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[48] + 0x8F1BBCDC;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[49] + 0x8F1BBCDC;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[50] + 0x8F1BBCDC;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[51] + 0x8F1BBCDC;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[52] + 0x8F1BBCDC;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[53] + 0x8F1BBCDC;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[54] + 0x8F1BBCDC;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[55] + 0x8F1BBCDC;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[56] + 0x8F1BBCDC;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[57] + 0x8F1BBCDC;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[58] + 0x8F1BBCDC;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[59] + 0x8F1BBCDC;    C = (C << 30) | (C >>> -30);
 
    // round 4
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[60] + 0xCA62C1D6;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[61] + 0xCA62C1D6;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[62] + 0xCA62C1D6;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[63] + 0xCA62C1D6;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[64] + 0xCA62C1D6;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[65] + 0xCA62C1D6;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[66] + 0xCA62C1D6;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[67] + 0xCA62C1D6;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[68] + 0xCA62C1D6;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[69] + 0xCA62C1D6;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[70] + 0xCA62C1D6;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[71] + 0xCA62C1D6;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[72] + 0xCA62C1D6;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[73] + 0xCA62C1D6;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[74] + 0xCA62C1D6;    C = (C << 30) | (C >>> -30);
 
    E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[75] + 0xCA62C1D6;    B = (B << 30) | (B >>> -30);
    D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[76] + 0xCA62C1D6;    A = (A << 30) | (A >>> -30);
    C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[77] + 0xCA62C1D6;    E = (E << 30) | (E >>> -30);
    B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[78] + 0xCA62C1D6;    D = (D << 30) | (D >>> -30);
    A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[79] + 0xCA62C1D6;    C = (C << 30) | (C >>> -30);
 
    // add this chunk's hash to result so far
    StaticHashValue.A += A;
    StaticHashValue.B += B;
    StaticHashValue.C += C;
    StaticHashValue.D += D;
    StaticHashValue.E += E;
 
    chunk++;
  }
}

