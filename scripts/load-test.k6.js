import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// 自定义指标
const degradedRatio = new Rate('degraded_ratio');
const backfillSuccess = new Rate('backfill_success_rate');
const cycleDuration = new Trend('cycle_duration_ms');
const throughput = new Counter('throughput_total');
const errors = new Counter('errors_total');

// 全局配置
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const VUS = parseInt(__ENV.VUS) || 10;
const DURATION = __ENV.DURATION || '60s';

export const options = {
  stages: [
    { duration: '30s', target: VUS * 0.2 },  // 预热
    { duration: '30s', target: VUS * 0.5 },  // 爬坡
    { duration: DURATION, target: VUS },      // 稳态压测
    { duration: '30s', target: VUS * 0.2 },  // 降压
    { duration: '10s', target: 0 },          // 冷却
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'],
    'http_req_failed': ['rate<0.01'],
    'degraded_ratio': ['rate<0.2'],
    'backfill_success_rate': ['rate>0.9'],
    'cycle_duration_ms': ['p(95)<1000'],
  },
};

// 权重随机选择：主要跑认知循环，少量健康检查
const ENDPOINTS = [
  { path: '/cycle', weight: 80 },      // 核心认知循环
  { path: '/health', weight: 10 },     // 健康检查
  { path: '/metrics', weight: 10 },    // 指标采集
];

function pickEndpoint() {
  const r = Math.random() * 100;
  let acc = 0;
  for (const ep of ENDPOINTS) {
    acc += ep.weight;
    if (r <= acc) return ep.path;
  }
  return '/cycle';
}

export default function () {
  const endpoint = pickEndpoint();
  const url = `${BASE_URL}${endpoint}`;
  
  const start = Date.now();
  let res;
  
  if (endpoint === '/cycle') {
    // 认知循环：POST JSON
    const payload = JSON.stringify({
      text: `Load test request ${__ITER}`,
      config: {
        energy_budget: 1.0,
        feedback_threshold: 0.8,
        snapshot_every: 5,
        enable_persistence: true,
      },
    });
    res = http.post(url, payload, {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'cycle' },
    });
  } else {
    res = http.get(url, { tags: { endpoint } });
  }
  
  const duration = Date.now() - start;
  cycleDuration.add(duration);
  throughput.add(1);
  
  // 基础检查
  const ok = check(res, {
    'status 2xx': (r) => r.status >= 200 && r.status < 300,
    'response time < 2s': () => duration < 2000,
  });
  
  if (!ok) {
    errors.add(1);
  }
  
  // 解析业务指标（仅 /cycle）
  if (endpoint === '/cycle' && res.status === 200) {
    try {
      const body = res.json();
      
      // 降级比例
      if (typeof body.degraded === 'boolean') {
        degradedRatio.add(!body.degraded); // degraded=false 即 OK
      } else if (typeof body.ok === 'number') {
        degradedRatio.add(body.ok === 1);
      }
      
      // 回灌成功率
      if (typeof body.backfill_success === 'boolean') {
        backfillSuccess.add(body.backfill_success);
      } else if (typeof body.backfill_success_rate === 'number') {
        backfillSuccess.add(body.backfill_success_rate > 0.9);
      }
      
      // 记录响应时间（毫秒）
      if (typeof body.latency_ms === 'number') {
        cycleDuration.add(body.latency_ms);
      }
    } catch (e) {
      // 非 JSON 或解析失败，忽略业务指标
    }
  }
  
  sleep(Math.random() * 0.2); // 0-200ms 思考时间
}

// 额外：定期健康检查
export function setup() {
  // 预热：发送几个请求确保服务就绪
  for (let i = 0; i < 5; i++) {
    http.get(`${BASE_URL}/health`);
    sleep(0.5);
  }
}

export function teardown() {
  // 清理逻辑（如需要）
}