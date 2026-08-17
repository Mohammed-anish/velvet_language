#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// A simple function that returns an integer
int double_num(int x) {
    return x * 2;
}

// A function that concatenates a string
char* greet(char* name) {
    char* greeting = malloc(strlen(name) + 8);
    strcpy(greeting, "Hello, ");
    strcat(greeting, name);
    return greeting;
}
