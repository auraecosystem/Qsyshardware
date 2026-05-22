#define LED_ADDR ((volatile unsigned int *)0x90000000u)
#define LED_MASK 0xFFu

static void delay(volatile int n) {
    while (n-- > 0) __asm__ volatile ("nop");
}

int main(void) {
    unsigned int val = 255u;
    for (;;) {
        /* divide por 2 repetidamente ate chegar em 1 */
        while (val >= 1) {
            *LED_ADDR = val & LED_MASK;
            delay(6000000);
            val = val / 2u;  /* usa DIV se compilado com rv32im */
        }
        /* reinicia */
        val = 255u;
        *LED_ADDR = 0x00u;
        delay(3000000);
    }
    return 0;
}
