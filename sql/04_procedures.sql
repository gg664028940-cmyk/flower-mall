-- ============================================================
-- 存储过程（2个，均有真实花店业务场景）
-- 依赖：01/02/03 已执行
-- ① sp_close_timeout_orders  未支付订单超时关单并回补库存（电商标配逻辑）
-- ② sp_sales_monthly_report  月度销售报表（日粒度汇总 + 热销花材TOP5）
-- ============================================================
USE flower_mall_db;

DROP PROCEDURE IF EXISTS `sp_close_timeout_orders`;
DELIMITER $$
-- 场景：顾客下单未支付，库存已被占用；长时间不支付则库存白白锁死。
-- 白兰花店惯例：超过 p_timeout_minutes 未支付的订单自动关闭（status=-2超时关闭）
-- 并把占用库存加回商品表。old baybee 项目预留了 -2 状态但没实现，本过程补全该逻辑。
CREATE PROCEDURE `sp_close_timeout_orders`(IN `p_timeout_minutes` INT)
BEGIN
  DECLARE `v_order_id`   BIGINT UNSIGNED DEFAULT 0;
  DECLARE `v_count`      INT DEFAULT 0;
  DECLARE `v_done`       TINYINT DEFAULT 0;
  -- 游标：捞取待支付且已超过时限的订单（只读不锁全表）
  DECLARE `cur_orders` CURSOR FOR
    SELECT `order_id`
    FROM `tb_flower_order`
    WHERE `order_status` = 0
      AND `create_time` < NOW() - INTERVAL `p_timeout_minutes` MINUTE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET `v_done` = 1;
  -- 任一SQL出错：整体回滚并报告（事务=要么全关单回补，要么什么都不做）
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
      ROLLBACK;
      SELECT 'sp_close_timeout_orders 出错，已回滚' AS `result`;
    END;

  START TRANSACTION;
  OPEN `cur_orders`;
  read_loop: LOOP
    FETCH `cur_orders` INTO `v_order_id`;
    IF `v_done` = 1 THEN LEAVE read_loop; END IF;

    -- 1) 库存回补：订单每个明细行的数量加回商品库存
    UPDATE `tb_flower_goods` g
    JOIN `tb_flower_order_item` oi ON oi.`goods_id` = g.`goods_id`
    SET g.`stock_num` = g.`stock_num` + oi.`goods_count`
    WHERE oi.`order_id` = `v_order_id`;

    -- 2) 订单置为超时关闭（-2）
    UPDATE `tb_flower_order`
    SET `order_status` = -2
    WHERE `order_id` = `v_order_id` AND `order_status` = 0;

    SET `v_count` = `v_count` + 1;
  END LOOP;
  CLOSE `cur_orders`;
  COMMIT;

  SELECT CONCAT('共关闭超时未支付订单 ', `v_count`, ' 笔，库存已回补') AS `result`;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_sales_monthly_report`;
DELIMITER $$
-- 场景：花店老板每月复盘——"这个月哪几天卖得好？哪些花材好卖？"
-- 入参：年、月。返回两个结果集：①日粒度销售汇总 ②热销花材TOP5（按订单快照统计）
CREATE PROCEDURE `sp_sales_monthly_report`(IN `p_year` INT, IN `p_month` INT)
BEGIN
  -- ① 日粒度汇总（只统计已支付订单）
  SELECT DATE(o.`create_time`) AS `sale_date`,
         COUNT(DISTINCT o.`order_id`) AS `order_count`,
         SUM(oi.`goods_count`)        AS `sold_qty`,
         SUM(oi.`selling_price`*oi.`goods_count`) AS `sales_amount`
  FROM `tb_flower_order` o
  JOIN `tb_flower_order_item` oi ON oi.`order_id` = o.`order_id`
  WHERE o.`pay_status` = 1 AND o.`is_deleted` = 0
    AND YEAR(o.`create_time`) = `p_year` AND MONTH(o.`create_time`) = `p_month`
  GROUP BY DATE(o.`create_time`);

  -- ② 热销花材TOP5：按快照中的主花材聚合（商品改名不影响历史统计）
  SELECT oi.`flower_material` AS `花材`,
         SUM(oi.`goods_count`) AS `销量`,
         SUM(oi.`selling_price`*oi.`goods_count`) AS `销售额`
  FROM `tb_flower_order_item` oi
  JOIN `tb_flower_order` o ON o.`order_id` = oi.`order_id`
  WHERE o.`pay_status` = 1 AND o.`is_deleted` = 0
    AND YEAR(o.`create_time`) = `p_year` AND MONTH(o.`create_time`) = `p_month`
  GROUP BY oi.`flower_material`
  ORDER BY `销量` DESC
  LIMIT 5;
END$$
DELIMITER ;
