-- ============================================================
-- SQL性能优化实验：100万行行为日志表上的三级对比
-- 前提：07_generate_bigdata.sql 已灌入数据
-- 演示口径（与报告/答辩话术一致）：
--   实验A「用户行为时间线」：查某个用户的近期行为统计
--   实验B「用户偏好统计」  ：跨一批用户的类型分布统计
--   对比路径：无索引(全表扫描) → 复合索引(减少扫描+可能回表) → 覆盖索引(免回表)
-- 建议在命令行/图形工具逐步执行并截图：EXPLAIN 输出 + 耗时，即为报告素材
-- ============================================================
USE flower_mall_db;

-- ------------------------------------------------------------
-- 实验A：某用户近期行为统计（上线初期常见报表需求）
-- ------------------------------------------------------------
-- A0 优化前【执行计划】：预计 type=ALL（全表扫描），rows≈100万
EXPLAIN
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id = 2468 AND behavior_time >= '2025-08-01'
GROUP BY behavior_type;

-- A1 优化前【实测】：EXPLAIN ANALYZE 会带出真实耗时（报告截图用）
EXPLAIN ANALYZE
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id = 2468 AND behavior_time >= '2025-08-01'
GROUP BY behavior_type;

-- A2 建复合索引（最左列=等值过滤列 user_id，第二列=时间范围列 behavior_time）
CREATE INDEX idx_user_time ON tb_flower_user_behavior_log (`user_id`, `behavior_time`);

-- A3 优化后【执行计划】：type=ref，key=idx_user_time，rows 降到约 200
EXPLAIN
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id = 2468 AND behavior_time >= '2025-08-01'
GROUP BY behavior_type;

-- A4 优化后【实测】：耗时通常下降 2~3 个数量级
EXPLAIN ANALYZE
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id = 2468 AND behavior_time >= '2025-08-01'
GROUP BY behavior_type;

-- ------------------------------------------------------------
-- 实验B：跨用户偏好统计（运营分析常用）
-- ------------------------------------------------------------
-- B0 优化前【执行计划】：全表扫描
EXPLAIN
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id BETWEEN 1 AND 500
GROUP BY behavior_type;

-- B1 此时只有 idx_user_time：B 查询能用上它吗？（能否免回表？）
--    观察 Extra：没有 "Using index" —— 聚合列 behavior_type 不在索引里，要回表
EXPLAIN
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id BETWEEN 1 AND 500
GROUP BY behavior_type;

-- B2 建覆盖索引：把聚合列也放进索引 => 索引即答案，Extra 出现 "Using index"
CREATE INDEX idx_user_type ON tb_flower_user_behavior_log (`user_id`, `behavior_type`);

-- B3 覆盖后【执行计划】+【实测】：免回表，耗时进一步下降
EXPLAIN ANALYZE
SELECT behavior_type, COUNT(*) AS cnt
FROM tb_flower_user_behavior_log
WHERE user_id BETWEEN 1 AND 500
GROUP BY behavior_type;

-- ------------------------------------------------------------
-- 附：索引清单与时序（DROP 顺序备用，重建库时脚本会自然清空）
-- ------------------------------------------------------------
SHOW INDEX FROM tb_flower_user_behavior_log;
