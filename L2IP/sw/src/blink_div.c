/* blink_div.c
 * Demonstra a extensao M (DIV) no pipeline RV32IM.
 *
 * Fase 1 – Divide por 3 repetidamente:  2187 -> 729 -> 243 -> 81 -> 27 -> 9 -> 3 -> 1 -> 0
 *          Cada resultado e exibido nos 10 LEDs.
 *          Quando val chega a 0, encerra a fase.
 *
 * Fase 2 – Zero: apaga todos os LEDs.
 *
 * Fase 3 – Wave infinito: acende um LED por vez ida e volta, para sempre.
 *
 * IMPORTANTE: compilar com -march=rv32im para gerar instrucoes DIV reais.
 */

#define LED_ADDR  ((volatile unsigned int *)0x90000000u)
#define LED_MASK  0x3FFu   /* 10 bits */

static void delay(volatile int n)
{
    while (n-- > 0)
        __asm__ volatile ("nop");
}

int main(void)
{
    unsigned int val;
    int i;

    /* ---- Fase 1: divisoes por 3 ---- */
    val = 2187u;
    while (val > 0u) {
        *LED_ADDR = val & LED_MASK;
        delay(3000000);
        val = val / 3u;       /* usa DIVU se compilado com rv32im */
    }

    /* ---- Fase 2: chegou a zero -> apaga tudo ---- */
    *LED_ADDR = 0x000u;
    delay(800000);

    /* ---- Fase 3: wave infinito ---- */
    for (;;) {
        /* ida (direita -> esquerda) */
        for (i = 0; i < 10; i++) {
            *LED_ADDR = (1u << i);
            delay(600000);
        }

        /* volta (esquerda -> direita) */
        for (i = 8; i >= 0; i--) {
            *LED_ADDR = (1u << i);
            delay(600000);
        }
    }

    return 0;
}
