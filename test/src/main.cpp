#include <iostream>
#include "cat.h"
using namespace std;

int main() {
    Cat cat1;
    cat1.age = 5;
    Cat cat2;
    cat2.age = 2;
    cat1.Say();
    cat2.Say();
    return 0;
}
