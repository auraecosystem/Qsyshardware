#define LED_ADDR ((volatile unsigned int *)0x90000000u)
#define LED_MASK 0xFFu

static void delay(volatile int n) {
    while (n-- > 0) __asm__ volatile ("nop");
}

int main(void) {
    volatile unsigned int divisor = 3u;
    unsigned int val = 243u;
    for (;;) {
        while (val >= 1u) {
            *LED_ADDR = val & LED_MASK;
            delay(6000000);
            val = val / divisor;
        }
        val = 243u;
        *LED_ADDR = 0x00u;
        delay(3000000);
    }
    return 0;
}
