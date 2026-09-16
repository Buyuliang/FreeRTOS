#include <stddef.h>
void *memset(void *d,int c,size_t n){ unsigned char *p=d; while(n--) *p++=(unsigned char)c; return d; }
void *memcpy(void *d,const void *s,size_t n){ unsigned char *pd=d; const unsigned char *ps=s; while(n--) *pd++=*ps++; return d; }
void *memmove(void *d,const void *s,size_t n){ unsigned char *pd=d; const unsigned char *ps=s;
    if(pd<ps){ while(n--) *pd++=*ps++; } else { pd+=n; ps+=n; while(n--) *--pd=*--ps; } return d; }
int memcmp(const void *a,const void *b,size_t n){ const unsigned char *x=a,*y=b;
    while(n--){ if(*x!=*y) return *x-*y; x++; y++; } return 0; }
size_t strlen(const char *s){ const char *p=s; while(*p) p++; return (size_t)(p-s); }
char *strncpy(char *d,const char *s,size_t n){ char *r=d; while(n&&*s){ *d++=*s++; n--; } while(n--) *d++=0; return r; }
char *strcpy(char *d,const char *s){ char *r=d; while((*d++=*s++)); return r; }
