#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SIZE 1024*1024
#define BUFSIZE (1024*1024*10)
static char buffer[BUFSIZE];

int main()
{
	char *bytes = (char *) malloc(SIZE);
	FILE *f = fopen("disk/test.txt", "wb");
	size_t size;
	int err;
	
	assert(f != NULL);
	memset(bytes, 'c', SIZE);
	err = setvbuf(f, buffer, _IOFBF, BUFSIZE);
	printf("setvbuf err: %d\n", err);
	size = fwrite(bytes, SIZE, 1, f);
	printf("size: %lu\n", size);
	err = fclose(f);
	printf("fclose err: %d. errno: %d: %s\n", err, errno, strerror(errno));
	return 0;
}
