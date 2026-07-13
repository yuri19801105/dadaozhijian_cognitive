#!/usr/bin/env python3
import json, sys, os

BASELINES = {
    "bench_core.json": {"vector_add_v8": 7.2, "tensor_add_3x3": 10.8, "softmax_len8": 718.8, "exp_scalar": 16.8},
    "bench_wuxing.json": {"sheng_ke": 6.0, "schedule": 210.0, "propagate": 420.0, "rebalance": 420.0},
    "bench_liuhe.json": {"build_supply": 213.6, "merge": 0.1},
    "bench_qixing.json": {"order_chain": 571.2, "priority_of": 217.2, "build_sequence": 608.4},
    "bench_scheduler.json": {"dispatch": 584.4, "dispatch_from_phase": 799.2},
    "bench_pipeline.json": {"run_pipeline": 1196.4, "run_pipeline_from_energies": 1100.4},
    "bench_shifang.json": {"fanout": 2520.0},
    "bench_runtime.json": {"lifecycle": 0.1, "memory": 2.4, "concurrency": 4.8, "backfill_supervisor": 3840.0},
    "bench_obs.json": {"metrics": 46.8, "trace": 2722.8, "render": 11462.4, "prometheus": 2160.0},
}

def check(file, baseline):
    with open(file) as f:
        data = json.load(f)
    ok = True
    for k, limit in baseline.items():
        actual = data.get(k)
        if actual is None:
            print(f"⚠️  {file}: missing key {k}")
            continue
        if actual > limit:
            print(f"❌ REGRESSION: {file}.{k} = {actual:.1f}ns > limit {limit:.1f}ns (1.2× baseline)")
            ok = False
        else:
            print(f"✅ {file}.{k} = {actual:.1f}ns ≤ {limit:.1f}ns")
    return ok

if __name__ == "__main__":
    all_ok = True
    for f, b in BASELINES.items():
        if os.path.exists(f):
            all_ok &= check(f, b)
        else:
            print(f"⚠️  {f} not found")
    sys.exit(0 if all_ok else 1)