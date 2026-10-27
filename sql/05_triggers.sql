-- ============================================================
-- 触发器（3条业务规则 / 4个触发器对象）
-- 依赖：01/02/03 已执行
-- 规则A 订单状态机守卫：非法状态跳变在数据库层直接拒绝（最后防线）
-- 规则B 售罄自动下架：库存清零即自动下架，防止页面继续可买
-- 规则C 分类树结构校验：层级-父子配对（替代被MySQL禁止的CHECK，见01注释）
-- ============================================================
USE flower_mall_db;

DELIMITER $$

-- ------------------------------------------------------------
-- 规则A：订单状态机守卫（BEFORE UPDATE ON order）
-- 业务场景：订单流转必须按 业务路径 完成：
--   0待支付 → 1已支付 → (2配货完成 →) 3出库成功 → 4交易成功
--   任意未终态 → -1/-2/-3 关闭；
--   不允许跳步（如直接从待支付改成"交易成功"）。
-- 为什么放DB层：状态跳变是硬规则，应用层可能有多个入口（后台/脚本/运维SQL），
-- 数据库层守住"最后防线"才完整。
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_order_status_guard`$$
CREATE TRIGGER `trg_order_status_guard`
BEFORE UPDATE ON `tb_flower_order`
FOR EACH ROW
BEGIN
  IF NEW.`order_status` <> OLD.`order_status` THEN
    -- 同值更新（其他字段变化）放行；只有状态变化才校验
    IF NOT (
         (OLD.`order_status` = 0 AND NEW.`order_status` IN (1,-1,-2,-3))
      OR (OLD.`order_status` = 1 AND NEW.`order_status` IN (2,3,-1,-2,-3))
      OR (OLD.`order_status` = 2 AND NEW.`order_status` IN (3,-1,-2,-3))
      OR (OLD.`order_status` = 3 AND NEW.`order_status` IN (4,-1,-2,-3))
      OR (OLD.`order_status` IN (-1,-2,-3) AND NEW.`order_status` = OLD.`order_status`)
    ) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '非法订单状态跳变：必须遵循 0→1→(2)→3→4 或关闭路径';
    END IF;
  END IF;
END$$

-- ------------------------------------------------------------
-- 规则B：售罄自动下架（BEFORE UPDATE ON goods）
-- 业务场景：鲜花卖断货后页面还挂着"可下单"会引发客诉；
-- 库存一旦清零，本触发器在数据落库瞬间把上架状态一并置0。
-- （说明：后台手动下架/上架仍可操作；关单回补后需人工重新上架——已知取舍，见报告）
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_goods_auto_delist`$$
CREATE TRIGGER `trg_goods_auto_delist`
BEFORE UPDATE ON `tb_flower_goods`
FOR EACH ROW
BEGIN
  IF NEW.`stock_num` <= 0 AND OLD.`goods_sell_status` = 1 THEN
    SET NEW.`goods_sell_status` = 0;
  END IF;
END$$

-- ------------------------------------------------------------
-- 规则C：分类树结构校验（INSERT 与 UPDATE 各一个触发器对象）
-- 业务场景：类目树一旦脏（二级挂到三级下/一级挂了父级），前台导航全部乱掉；
-- MySQL 的 CHECK 不支持"引用其他行"（已实测 ERROR 3823：外键列还禁入CHECK），
-- 故用触发器做跨行校验。
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_category_parent_insert`$$
CREATE TRIGGER `trg_category_parent_insert`
BEFORE INSERT ON `tb_flower_category`
FOR EACH ROW
BEGIN
  DECLARE `v_parent_level` TINYINT;
  IF NEW.`category_level` = 1 THEN
    IF NEW.`parent_id` <> 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '一级分类的 parent_id 必须为 0';
    END IF;
  ELSE
    SELECT `category_level` INTO `v_parent_level`
    FROM `tb_flower_category`
    WHERE `category_id` = NEW.`parent_id`;
    IF `v_parent_level` IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '父分类不存在';
    END IF;
    IF NEW.`category_level` = 2 AND `v_parent_level` <> 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '二级分类必须挂在一级分类下';
    END IF;
    IF NEW.`category_level` = 3 AND `v_parent_level` <> 2 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '三级分类必须挂在二级分类下';
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS `trg_category_parent_update`$$
CREATE TRIGGER `trg_category_parent_update`
BEFORE UPDATE ON `tb_flower_category`
FOR EACH ROW
BEGIN
  DECLARE `v_parent_level` TINYINT;
  IF NEW.`category_level` = 1 THEN
    IF NEW.`parent_id` <> 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '一级分类的 parent_id 必须为 0';
    END IF;
  ELSE
    SELECT `category_level` INTO `v_parent_level`
    FROM `tb_flower_category`
    WHERE `category_id` = NEW.`parent_id`;
    IF `v_parent_level` IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '父分类不存在';
    END IF;
    IF NEW.`category_level` = 2 AND `v_parent_level` <> 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '二级分类必须挂在一级分类下';
    END IF;
    IF NEW.`category_level` = 3 AND `v_parent_level` <> 2 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '三级分类必须挂在二级分类下';
    END IF;
  END IF;
END$$

DELIMITER ;
