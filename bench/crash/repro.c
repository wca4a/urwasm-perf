// standalone repro: load a module and m3_CompileModule it, as the urwasm jet does on first load
#include <stdio.h>
#include <stdlib.h>
#include "wasm3.h"
static void* re(void* p, size_t o, size_t n){ return realloc(p, n); }
int main(int argc, char** argv) {
  FILE* f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f);
  unsigned char* b = malloc(n); fread(b, 1, n, f); fclose(f);
  m3_SetAllocators(calloc, free, re); m3_SetTransientAllocators(calloc, free, re); m3_SetMemoryAllocators(calloc, free, re);
  IM3Environment env = m3_NewEnvironment();
  IM3Runtime rt = m3_NewRuntime(env, 1 << 21, NULL, argc > 2 ? atoi(argv[2]) : 1);
  IM3Module mod; M3Result r;
  if ((r = m3_ParseModule(env, &mod, b, n))) { printf("parse: %s\n", r); return 1; }
  if ((r = m3_LoadModule(rt, mod))) { printf("load: %s\n", r); return 1; }
  if ((r = m3_ValidateModule(mod))) { printf("validate: %s\n", r); return 1; }
  if ((r = m3_CompileModule(mod))) { printf("compile: %s\n", r); return 1; }
  IM3Function fn; if ((r = m3_FindFunction(&fn, rt, "all"))) { printf("find: %s\n", r); return 1; }
  const char* a[] = {"1"}; if ((r = m3_CallArgv(fn, 1, a))) { printf("call: %s\n", r); return 1; }
  unsigned v; const void* p[] = {&v}; m3_GetResults(fn, 1, p); printf("ok all(1)=%u\n", v); return 0;
}
