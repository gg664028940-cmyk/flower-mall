-- ============================================================
-- 性能测试专用表批量数据生成（目标：100万行）
-- 执行前提：01_schema.sql 已建库（其余脚本无关）
-- 方案：MySQL 8.0+ 递归 CTE 单条 INSERT 批量生成（无需外部程序）
-- 说明（答辩点）：
--   1. cte_max_recursion_depth 需放宽到 ≥100万（默认1000，专为深递归设计）
--   2. 数据按业务分布模拟：浏览/加购/收藏带商品id；搜索类型带热搜词；
--      user_id 取 1~5000 合成用户（日志表刻意无外键，见01建表说明）
--   3. 行为时间分布在前2年内（支撑"按用户+时间段查询"的真实场景）
--   4. 灌完后 ANALYZE TABLE 刷新统计信息，保证执行计划实验可靠
-- 换算参考：100万行在本脚本下通常 < 1分钟；机器更强且想要更炫对比可改 1000万
-- ============================================================
USE flower_mall_db;

SET SESSION cte_max_recursion_depth = 1000000;

TRUNCATE TABLE `tb_flower_user_behavior_log`;

INSERT INTO `tb_flower_user_behavior_log`
    (`user_id`, `goods_id`, `behavior_type`, `search_keyword`, `behavior_time`)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 1000000
)
SELECT
    FLOOR(1 + RAND() * 5000)                                            AS user_id,
    CASE WHEN RAND() < 0.85 THEN 1000 + FLOOR(1 + RAND() * 25) ELSE NULL END AS goods_id,
    CASE
        WHEN RAND() < 0.70 THEN 1   -- 70% 浏览
        WHEN RAND() < 0.85 THEN 2   -- ~15% 搜索
        WHEN RAND() < 0.95 THEN 3   -- ~10% 加购
        ELSE 4                       -- ~5% 收藏
    END                                                                  AS behavior_type,
    CASE WHEN RAND() < 0.30 THEN
        ELT(1 + FLOOR(RAND() * 6), '红玫瑰花束','向日葵花束','生日花束','百合花束','多肉','永生花盒')
    ELSE NULL END                                                        AS search_keyword,
    FROM_UNIXTIME(UNIX_TIMESTAMP('2024-10-01') + FLOOR(RAND() * 62640000)) AS behavior_time
FROM seq;

ANALYZE TABLE `tb_flower_user_behavior_log`;

-- 完成校验
SELECT COUNT(*) AS total_rows,
       MIN(behavior_time) AS earliest,
       MAX(behavior_time) AS latest
FROM `tb_flower_user_behavior_log`;
