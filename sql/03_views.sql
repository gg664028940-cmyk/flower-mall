-- ============================================================
-- 视图（3个，每个都有明确业务必要性）
-- 依赖：01_schema.sql + 02_seed_data.sql 已执行
-- ============================================================
USE flower_mall_db;

DROP VIEW IF EXISTS `v_on_sale_catalog`;
-- 【视图1】在售商品目录：前台"分类筛选/搜索/列表"的统一口径
-- 必要性：任何列表页都要联三级分类并过滤下架/逻辑删除，口径固化一处，避免写漂移。
CREATE VIEW `v_on_sale_catalog` AS
SELECT g.`goods_id`, g.`goods_name`, g.`goods_intro`, g.`selling_price`,
       g.`flower_material`, g.`flower_color`, g.`flower_form`,
       g.`stock_num`, g.`tag`, g.`goods_cover_img`,
       c3.`category_name` AS `category_name_lv3`,
       c2.`category_name` AS `category_name_lv2`,
       c1.`category_name` AS `category_name_lv1`
FROM `tb_flower_goods` g
JOIN `tb_flower_category` c3 ON g.`goods_category_id` = c3.`category_id`
JOIN `tb_flower_category` c2 ON c3.`parent_id` = c2.`category_id`
JOIN `tb_flower_category` c1 ON c2.`parent_id` = c1.`category_id`
WHERE g.`goods_sell_status` = 1 AND g.`is_deleted` = 0;

DROP VIEW IF EXISTS `v_order_summary`;
-- 【视图2】订单汇总与对账：客服/对账场景
-- 必要性：核对"订单主表总价"与"明细加总"是否一致（amount_consistent=0 即问题单），
-- 同时为订单列表页提供件数/金额聚合口径。
CREATE VIEW `v_order_summary` AS
SELECT o.`order_id`, o.`order_no`, o.`user_id`, u.`nick_name`,
       o.`total_price`, o.`order_status`, o.`pay_status`, o.`pay_time`,
       o.`delivery_date`, o.`card_message`,
       COUNT(oi.`order_item_id`)                  AS `item_lines`,
       SUM(oi.`goods_count`)                      AS `item_total_qty`,
       SUM(oi.`selling_price` * oi.`goods_count`) AS `items_amount`,
       (o.`total_price` = SUM(oi.`selling_price` * oi.`goods_count`)) AS `amount_consistent`
FROM `tb_flower_order` o
JOIN `tb_flower_order_item` oi ON oi.`order_id` = o.`order_id`
JOIN `tb_flower_user` u ON u.`user_id` = o.`user_id`
WHERE o.`is_deleted` = 0
GROUP BY o.`order_id`, o.`order_no`, o.`user_id`, u.`nick_name`,
         o.`total_price`, o.`order_status`, o.`pay_status`, o.`pay_time`,
         o.`delivery_date`, o.`card_message`;

DROP VIEW IF EXISTS `v_low_stock_goods`;
-- 【视图3】低库存商品清单：花店每日备货提示
-- 必要性：鲜花保质期短、损耗快，库存低于备货线的商品需要每天拉出来提醒补货，
-- 否则页面挂着"可下单"实际已近售罄。本视图即"今天该补哪些货"的作业清单。
CREATE VIEW `v_low_stock_goods` AS
SELECT g.`goods_id`, g.`goods_name`, g.`flower_material`,
       g.`stock_num`, g.`safe_stock_num`, g.`selling_price`
FROM `tb_flower_goods` g
WHERE g.`is_deleted` = 0
  AND g.`goods_sell_status` = 1
  AND g.`stock_num` < g.`safe_stock_num`;
