#define LED_ADDR ((volatile unsigned int *)0x90000000u)
int main(void) {
    *LED_ADDR = 0x155;
    for(;;) {}
    return 0;
}
