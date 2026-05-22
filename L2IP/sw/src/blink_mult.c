/* blink_mult.c
 * Demonstra a extensao M (MUL) no pipeline RV32IM.
 *
 * Fase 1 – Multiplica por 3 repetidamente:  1 -> 3 -> 9 -> 27 -> 81 -> 243 -> 729
 *          Cada resultado e exibido nos 10 LEDs.
 *          Quando val * 3 > 1023 (10 bits), ocorre overflow.
 *
 * Fase 2 – Overflow: apaga todos os LEDs.
 *
 * Fase 3 – Wave: acende um LED por vez da direita pra esquerda e volta.
 *
 * Repete infinitamente.
 *
 * IMPORTANTE: compilar com -march=rv32im para gerar instrucoes MUL reais.
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

    /* ---- Fase 1: multiplicacoes por 3 ---- */
    val = 1u;
    while (val <= LED_MASK) {
        *LED_ADDR = val & LED_MASK;
        delay(30000000);
        val = val * 3u;       /* usa MUL se compilado com rv32im */
    }

    /* ---- Fase 2: overflow -> apaga tudo ---- */
    *LED_ADDR = 0x000u;
    delay(8000000);

    /* ---- Fase 3: wave infinito ---- */
    for (;;) {
        /* ida (direita -> esquerda) */
        for (i = 0; i < 10; i++) {
            *LED_ADDR = (1u << i);
            delay(6000000);
        }

        /* volta (esquerda -> direita) */
        for (i = 8; i >= 0; i--) {
            *LED_ADDR = (1u << i);
            delay(6000000);
        }
    }

    return 0;
}
