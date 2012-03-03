class Base64 extends Object;

var protected string LookupTable[64];

function string Encode(array<byte> in)
{
    local array<string> result;
    local string res;
    local int dl;
    local int i;

    if (LookupTable[0] == "") GenerateTable();

    dl = in.Length;

    if (dl % 3 == 1) {
        in[in.Length] = 0;
        in[in.Length] = 0;
    }
    if (dl % 3 == 2) {
        in[in.Length] = 0;
    }

    for (i = 0; i < dl; i += 3) {
        result.AddItem(LookupTable[(in[i] >> 2)]);
        result.AddItem(LookupTable[((in[i]&3)<<4) | (in[i+1]>>4)]);
        result.AddItem(LookupTable[((in[i+1]&15)<<2) | (in[i+2]>>6)]);
        result.AddItem(LookupTable[(in[i+2]&63)]);
    }
    if (dl % 3 == 1) {
        result[result.length - 1] = "=";
        result[result.length - 2] = "=";
    }
    if (dl % 3 == 2) {
        result[result.length - 1] = "=";
    }

    JoinArray(result, res, "", false);
    
    return res;
}

protected function GenerateTable()
{
    local int i;
    for (i = 0; i < 26; i++) {
            LookupTable[i] = Chr(i+65);
    }
    for (i = 0; i < 26; i++) {
            LookupTable[i+26] = Chr(i+97);
    }
    for (i = 0; i < 10; i++) {
            LookupTable[i+52] = Chr(i+48);
    }
    LookupTable[62] = "+";
    LookupTable[63] = "/";

}
