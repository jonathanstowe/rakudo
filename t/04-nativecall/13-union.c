#include <stdio.h>
#include <stdlib.h>

#ifdef WIN32
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT extern
#endif

typedef union {
    unsigned long  l;
    unsigned int   i;
    unsigned short s;
    unsigned char  c;
} onion;

/* Test for inlined union. */
typedef struct {
    long intval;
    double numval;
    char byteval;
    onion vegval;
    float floatval;
} MyStruct;

DLLEXPORT int SizeofMyStruct() {
    return sizeof(MyStruct);
}

DLLEXPORT MyStruct *ReturnMyStruct() {
    MyStruct *obj = (MyStruct *)malloc(sizeof(MyStruct));
    obj->intval   = 17;
    obj->numval   = 4.2;
    obj->byteval  = 13;

    obj->vegval.l = 0;
    obj->vegval.i = 1 << 30;
    obj->vegval.s = 1 << 14;
    obj->vegval.c = 1 << 6;

    obj->floatval = -6.28;

    return obj;
}

/* Test for referenced union. */
typedef struct {
    long intval;
    double numval;
    char byteval;
    onion* vegval;
    float floatval;
} MyStruct2;

DLLEXPORT int SizeofMyStruct2() {
    return sizeof(MyStruct2);
}

DLLEXPORT MyStruct2 *ReturnMyStruct2() {
    MyStruct2 *obj = (MyStruct2 *)malloc(sizeof(MyStruct2));
    obj->intval    = 17;
    obj->numval    = 4.2;
    obj->byteval   = 13;

    obj->vegval    = (onion *)malloc(sizeof(onion));
    obj->vegval->l = 0;
    obj->vegval->i = 1 << 30;
    obj->vegval->s = 1 << 14;
    obj->vegval->c = 1 << 6;

    obj->floatval  = -6.28;

    return obj;
}
