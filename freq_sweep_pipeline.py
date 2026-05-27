#!/usr/bin/env python3
"""
freq_sweep_pipeline.py
======================
Sweep de frequencia do core pipeline RV32IM (5 estagios).

Estrategia:
  1) Edita src/PLL/pll_0002.v alterando output_clock_frequency0/1/2 (3-way phases)
  2) Recompila Quartus (limpa db/incremental_db/output_files/simulation antes)
  3) Programa FPGA + carrega ROM via JTAG
  4) Aguarda WAIT_SECS, faz dump e compara contra gabarito
  5) Registra PASS/FAIL e prossegue (sweep linear OU busca binaria)

Modo padrao: SWEEP LINEAR. Use --binary para busca binaria do Fmax.

Uso (na raiz do repo):
  python3 freq_sweep_pipeline.py --start 1 --stop 30 --step 1
  python3 freq_sweep_pipeline.py --binary --low 1 --high 50
  python3 freq_sweep_pipeline.py --start 1 --stop 30 --step 1 --wait 35

Saidas:
  freq_sweep_results.json   - resultados estruturados
  freq_sweep.log            - log textual da rodada

Notas:
  - Como as 3 saidas do PLL (clk_if/clk_idexmem/clk_wb) sao a mesma freq
    em fases diferentes (0, 120, 240 graus), o script altera as tres juntas.
  - Os phase_shift sao reajustados proporcionalmente (1/3 do periodo cada).
  - Voltagem/temperatura nao sao controlados; resultado eh empirico naquela placa.
"""

import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# -------- Caminhos (relativos a raiz do repo) ---------------------------------
REPO_ROOT = Path(__file__).resolve().parent
PLL_FILE = REPO_ROOT / "src" / "PLL" / "pll_0002.v"
TEST_DIR = REPO_ROOT / "tests" / "FPGA" / "core"
LOG_FILE = REPO_ROOT / "freq_sweep.log"
RESULTS_FILE = REPO_ROOT / "freq_sweep_results.json"

# -------- Logging -------------------------------------------------------------
def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

# -------- PLL edit ------------------------------------------------------------
def set_pll_freq(mhz: float):
    """Edita pll_0002.v: output_clock_frequency0/1/2 = mhz, phase_shift ajustado."""
    if not PLL_FILE.exists():
        raise FileNotFoundError(f"PLL file not found: {PLL_FILE}")

    text = PLL_FILE.read_text()
    period_ps = int(round(1_000_000 / mhz))  # 1 MHz = 1_000_000 ps
    phase0 = 0
    phase1 = period_ps // 3
    phase2 = (2 * period_ps) // 3

    freq_str = f"{mhz:.6f}"

    def replace_clock(t, idx, ph):
        t = re.sub(
            rf'\.output_clock_frequency{idx}\("[^"]+"\)',
            f'.output_clock_frequency{idx}("{freq_str} MHz")',
            t
        )
        t = re.sub(
            rf'\.phase_shift{idx}\("[^"]+"\)',
            f'.phase_shift{idx}("{ph} ps")',
            t
        )
        return t

    text = replace_clock(text, 0, phase0)
    text = replace_clock(text, 1, phase1)
    text = replace_clock(text, 2, phase2)

    PLL_FILE.write_text(text)
    log(f"  PLL set: {mhz} MHz, phases 0/{phase1}/{phase2} ps (period={period_ps} ps)")

def get_current_pll_freq():
    text = PLL_FILE.read_text()
    m = re.search(r'\.output_clock_frequency0\("([\d.]+)\s*MHz"\)', text)
    return float(m.group(1)) if m else None

# -------- Comandos shell ------------------------------------------------------
def run_cmd(cmd, cwd=None, timeout=None, check=False):
    log(f"  $ {cmd}")
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=cwd, timeout=timeout,
            capture_output=True, text=True
        )
        if check and result.returncode != 0:
            log(f"  ! exit={result.returncode}")
            log(f"  ! stderr: {result.stderr[-300:]}")
        return result
    except subprocess.TimeoutExpired:
        log(f"  ! TIMEOUT after {timeout}s")
        return None

# -------- Fluxo de teste para uma frequencia ----------------------------------
def test_at_freq(mhz: float, wait_secs: int = 35) -> dict:
    log(f"=== Teste em {mhz} MHz ===")
    set_pll_freq(mhz)

    # 1) Limpa cache do Quartus
    run_cmd(
        "sudo rm -rf quartus/db quartus/incremental_db quartus/output_files quartus/simulation build output_mifs",
        cwd=TEST_DIR
    )

    # 2) Compila
    t0 = time.time()
    result = run_cmd("make quartus_compile", cwd=TEST_DIR, timeout=600)
    compile_time = time.time() - t0
    if result is None or result.returncode != 0:
        log(f"  ! Compile falhou em {mhz} MHz")
        return {
            "freq_mhz": mhz, "status": "compile_fail",
            "compile_time_s": compile_time
        }
    log(f"  compile OK em {compile_time:.1f}s")

    # 3) Programa
    result = run_cmd(
        'quartus_pgm -m JTAG -o "p;quartus/output_files/core_fpga_test.sof"',
        cwd=TEST_DIR, timeout=120
    )
    if result is None or result.returncode != 0:
        return {"freq_mhz": mhz, "status": "program_fail"}

    # 4) Hex2mif e loadROM
    result = run_cmd(
        "python3 tools/hex2mif.py build/full.hex /tmp/rom_jtag.mif 8192",
        cwd=TEST_DIR, timeout=60
    )
    if result is None or result.returncode != 0:
        return {"freq_mhz": mhz, "status": "hex2mif_fail"}

    result = run_cmd(
        "quartus_stp -t tools/loadROM.tcl /tmp/rom_jtag.mif",
        cwd=TEST_DIR, timeout=120
    )
    if result is None or result.returncode != 0:
        return {"freq_mhz": mhz, "status": "loadrom_fail"}

    # 5) Espera execucao
    log(f"  aguardando {wait_secs}s para programa executar...")
    time.sleep(wait_secs)

    # 6) Dump da RAM
    run_cmd("mkdir -p output_mifs", cwd=TEST_DIR)
    result = run_cmd(
        "quartus_stp -t tools/dumpMemory.tcl output_mifs/full_ram.mif 1",
        cwd=TEST_DIR, timeout=120
    )
    if result is None or result.returncode != 0:
        return {"freq_mhz": mhz, "status": "dump_fail"}

    # 7) Compara contra gabarito
    result = run_cmd(
        "python3 tools/compare_mif_with_json.py output_mifs/full_ram.mif asm_tests/full.json",
        cwd=TEST_DIR, timeout=60
    )
    if result is None:
        return {"freq_mhz": mhz, "status": "compare_timeout"}

    # exit 0 = PASS, exit 2 = FAIL (diffs encontrados)
    if result.returncode == 0:
        log(f"  PASS @ {mhz} MHz")
        return {"freq_mhz": mhz, "status": "pass", "compile_time_s": compile_time}
    else:
        # Conta diffs do stdout
        out = result.stdout or ""
        m = re.search(r"Total diffs: (\d+)", out)
        diffs = int(m.group(1)) if m else -1
        log(f"  FAIL @ {mhz} MHz (diffs={diffs})")
        return {
            "freq_mhz": mhz, "status": "fail",
            "diffs": diffs, "compile_time_s": compile_time
        }

# -------- Estrategias ---------------------------------------------------------
def linear_sweep(start, stop, step, wait_secs):
    results = []
    freqs = []
    f = start
    while f <= stop + 1e-6:
        freqs.append(round(f, 3))
        f += step

    for mhz in freqs:
        r = test_at_freq(mhz, wait_secs)
        results.append(r)
        save_results(results)

        # Para cedo: 3 falhas consecutivas indica que ja passou do Fmax
        if len(results) >= 3 and all(
            x["status"] != "pass" for x in results[-3:]
        ):
            log(f"3 falhas consecutivas -> parando sweep (Fmax provavel ja encontrado)")
            break

    return results

def binary_search(low, high, wait_secs, tolerance=0.5):
    """Busca o Fmax do core entre low e high MHz."""
    results = []

    # Sanidade: testa o lower limit
    r = test_at_freq(low, wait_secs)
    results.append(r)
    save_results(results)
    if r["status"] != "pass":
        log(f"FAIL no limite inferior {low} MHz -> abortando")
        return results

    # Testa o upper limit
    r = test_at_freq(high, wait_secs)
    results.append(r)
    save_results(results)
    if r["status"] == "pass":
        log(f"PASS no limite superior {high} MHz -> Fmax > high (aumente high)")
        return results

    # Busca binaria entre low (PASS) e high (FAIL)
    lo, hi = low, high
    while (hi - lo) > tolerance:
        mid = round((lo + hi) / 2, 1)
        log(f"== Busca binaria: lo={lo}, hi={hi}, testando mid={mid} ==")
        r = test_at_freq(mid, wait_secs)
        results.append(r)
        save_results(results)
        if r["status"] == "pass":
            lo = mid
        else:
            hi = mid

    log(f"Busca convergiu: Fmax estimado entre {lo} e {hi} MHz")
    return results

# -------- Persistencia --------------------------------------------------------
def save_results(results):
    RESULTS_FILE.write_text(json.dumps(results, indent=2))

# -------- Main ----------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=float, default=1.0, help="freq inicial (MHz)")
    ap.add_argument("--stop",  type=float, default=30.0, help="freq final (MHz)")
    ap.add_argument("--step",  type=float, default=2.0,  help="passo (MHz)")
    ap.add_argument("--binary", action="store_true",
                    help="busca binaria em vez de sweep linear")
    ap.add_argument("--low",   type=float, default=1.0, help="(binary) low MHz")
    ap.add_argument("--high",  type=float, default=50.0, help="(binary) high MHz")
    ap.add_argument("--wait",  type=int,   default=35,  help="segundos antes do dump")
    ap.add_argument("--restore", type=float, default=None,
                    help="No fim, restaura PLL a este valor (MHz)")
    args = ap.parse_args()

    # Reset log
    LOG_FILE.write_text(f"# Sweep iniciado em {datetime.now().isoformat()}\n")
    initial_freq = get_current_pll_freq()
    log(f"PLL inicial: {initial_freq} MHz")
    log(f"REPO_ROOT: {REPO_ROOT}")
    log(f"PLL_FILE:  {PLL_FILE}")

    if args.binary:
        results = binary_search(args.low, args.high, args.wait)
    else:
        results = linear_sweep(args.start, args.stop, args.step, args.wait)

    save_results(results)

    # Sumario
    log("=" * 60)
    log("SUMARIO:")
    for r in results:
        extra = f" diffs={r.get('diffs', '-')}" if r["status"] == "fail" else ""
        log(f"  {r['freq_mhz']:6.2f} MHz : {r['status']:12s}{extra}")

    passes = [r["freq_mhz"] for r in results if r["status"] == "pass"]
    if passes:
        log(f"Maior frequencia que passou: {max(passes)} MHz")

    if args.restore is not None:
        log(f"Restaurando PLL para {args.restore} MHz")
        set_pll_freq(args.restore)

if __name__ == "__main__":
    main()
