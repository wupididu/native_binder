# NativeBinder Performance Benchmark Results

## Test Configuration

| Property | Value |
|----------|-------|
| **Date** | 2026-02-22 05:38 |
| **Iterations** | 2000 |
| **Platform** | ANDROID |
| **OS Version** | AE3A.240806.036 |
| **Device** | Unknown |
| **Flutter Version** | Unknown |
| **Dart Version** | 3.7.0-243.0.dev |

## Summary

- **Average Speedup:** 3.8x faster than MethodChannel
- **Maximum Speedup:** 6.0x (List 100 ints)

## Benchmark Results

All times in microseconds (µs).

| Scenario | NB Mean±SD | MC Mean±SD | NB P95/P99 | MC P95/P99 | Speedup |
|----------|------------|------------|------------|------------|---------|
| Int pass-through | 67.5±167 | 349±1699 | 86.0/265 | 1327/6050 | **5.2x** |
| String 1 KB | 91.1±580 | 317±1484 | 78.0/844 | 1277/4673 | **3.5x** |
| String 10 KB | 174±539 | 474±1972 | 254/1926 | 2116/6177 | **2.7x** |
| String 100 KB | 761±1058 | 2374±5075 | 1324/4956 | 8015/23694 | **3.1x** |
| List 100 ints | 49.9±148 | 300±1132 | 60.0/204 | 1063/5164 | **6.0x** |
| List 1K ints | 336±591 | 1074±2481 | 784/2430 | 4652/8917 | **3.2x** |
| List 10K ints | 2454±609 | 6843±4304 | 3323/4900 | 13449/22787 | **2.8x** |
| Map 100 entries | 154±227 | 705±2333 | 196/778 | 3129/7990 | **4.6x** |
| Map 1K entries | 1276±580 | 3795±4785 | 1937/2872 | 10742/21272 | **3.0x** |
| Nested structure | 451±287 | 1548±3298 | 707/1515 | 5997/11462 | **3.4x** |
| Mixed list | 183±265 | 745±2002 | 226/913 | 3609/8984 | **4.1x** |

### Timing Breakdown by Phase

| Scenario | Encode (µs) | Native (µs) | Decode (µs) | Total (µs) |
|----------|-------------|-------------|-------------|------------|
| Int pass-through | 0.51 | 65.4 | 1.51 | 67.5 |
| String 1 KB | 1.81 | 85.2 | 4.16 | 91.1 |
| String 10 KB | 15.7 | 147 | 11.0 | 174 |
| String 100 KB | 116 | 596 | 49.3 | 761 |
| List 100 ints | 3.47 | 45.2 | 1.19 | 49.9 |
| List 1K ints | 29.0 | 299 | 8.16 | 336 |
| List 10K ints | 220 | 2188 | 46.4 | 2454 |
| Map 100 entries | 10.8 | 132 | 11.1 | 154 |
| Map 1K entries | 73.0 | 1104 | 98.7 | 1276 |
| Nested structure | 23.9 | 398 | 28.8 | 451 |
| Mixed list | 15.1 | 159 | 9.47 | 183 |


## Interpretation

- **Encode**: Time spent encoding arguments in Dart using StandardMessageCodec
- **Native**: Time spent in FFI call + native execution (decode + handler + encode)
- **Decode**: Time spent decoding response in Dart
- **NB Total**: Total NativeBinder execution time (synchronous)
- **MC Total**: Total MethodChannel execution time (async)
- **Speedup**: Ratio of MethodChannel time to NativeBinder time

