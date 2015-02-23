#include <stdio.h>
#include <stdlib.h>

#ifdef WIN32
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT extern
#endif

typedef struct {
    long intval;
    double numval;
    char byteval;
    union {
        unsigned long  *l;
        unsigned int   *i;
        unsigned short *s;
        unsigned char  *c;
    } onion;
    float floatval;
    long *arr;
} MyStruct;

DLLEXPORT int SizeofMyStruct() {
    return sizeof(MyStruct);
}

DLLEXPORT MyStruct *ReturnMyStruct() {
    MyStruct *obj = (MyStruct *)malloc(sizeof(MyStruct));
    obj->intval = 17;
    obj->numval = 4.2;
    obj->byteval = 13;
    
    obj->onion.l  = (unsigned long *)malloc(sizeof(unsigned long));
    *obj->onion.l = 0;
    *obj->onion.i = 1 << 30;
    *obj->onion.s = 1 << 14;
    *obj->onion.c = 1 << 6;
    
    obj->floatval = -6.28;
    obj->arr = (long *)malloc(3*sizeof(long));
    obj->arr[0] = 2;
    obj->arr[1] = 3;
    obj->arr[2] = 5;

    return obj;
}
