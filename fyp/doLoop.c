#include <stdio.h>

int main(void){

        int x = 1;
        int y = 1;

        while (y < 10){
                x = x * 2;
                y = y + 1;
                printf("%d\n", y);

        }
        
        printf("%d\n", x);

        return 0;
}
