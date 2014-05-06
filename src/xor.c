#include <stdlib.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "No argument given.\n");
        exit(1);
    }
    char *filename = argv[1];

    FILE *file = fopen(filename, "r");
    if (file == NULL) {
        fprintf(stderr, "Could not open given file.\n");
        exit(1);
    }
    int c1;
    int c2;
    do {
        c1 = fgetc(stdin);
        c2 = fgetc(file);
        if (c1 == EOF) {
            while (c2 != EOF) {
                printf("%c", c2);
                c2 = fgetc(file);
            }
            break;
        } else  if (c2 == EOF) {
            while (c1 != EOF) {
                printf("%c", c1);
                c1 = fgetc(stdin);
            }
            break;
        }
        int c = c1 ^ c2;
        printf("%c", c);
    } while (1);

    exit(0);
}
