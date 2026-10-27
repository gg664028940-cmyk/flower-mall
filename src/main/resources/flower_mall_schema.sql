-- ============================================================
-- 鲜花商城系统建库脚本（合并版 = 鲜花商城课设/sql 的 01+02）
-- 课设主工程包在: 鲜花商城课设/ 目录（08个脚本+文档），本文件为应用随包副本，执行顺序 01→02 其余可选
-- ============================================================
-- ============================================================
-- 极简版物理设计：newbee-mall 商城结构 + 2026课设硬指标达标改造
-- 业务主线：一条—— 商城订单链（逛→加购→下单→支付→配货→出库→确认收货）
-- 设计原则：
--   1. 表结构与参考项目一一对应（高重合），仅三维改善：
--      ① 表名/数据主题鲜花化  ② 补落完整性约束（外键/唯一/CHECK）  ③ 鲜花必要属性
--   2. 只保留满足验收底线的对象数量：10 表 / 3 视图 / 2 触发器 / 2 存储过程
--   3. 价格存"分"（整型），删除全逻辑删除，utf8mb4。
-- ============================================================

DROP DATABASE IF EXISTS flower_mall_db;
CREATE DATABASE flower_mall_db DEFAULT CHARACTER SET utf8mb4;
USE flower_mall_db;

DROP TABLE IF EXISTS `tb_flower_user_behavior_log`;
DROP TABLE IF EXISTS `tb_flower_order_item`;
DROP TABLE IF EXISTS `tb_flower_cart_item`;
DROP TABLE IF EXISTS `tb_flower_order`;
DROP TABLE IF EXISTS `tb_flower_goods`;
DROP TABLE IF EXISTS `tb_flower_category`;
DROP TABLE IF EXISTS `tb_flower_index_config`;
DROP TABLE IF EXISTS `tb_flower_carousel`;
DROP TABLE IF EXISTS `tb_flower_user`;
DROP TABLE IF EXISTS `tb_flower_admin_user`;

-- 1 商城用户（实体）
CREATE TABLE `tb_flower_user` (
  `user_id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户主键',
  `nick_name`      VARCHAR(50)  NOT NULL COMMENT '昵称',
  `login_name`     VARCHAR(20)  NOT NULL COMMENT '登录名（手机号）',
  `password_md5`   CHAR(32)     NOT NULL COMMENT '密码摘要（MD5，报告说明弱点与bcrypt演进）',
  `phone`          VARCHAR(11)  NULL COMMENT '联系电话',
  `member_level`   TINYINT      NOT NULL DEFAULT 1 COMMENT '会员等级 1普通 2银卡 3金卡',
  `introduce_sign` VARCHAR(100) NULL COMMENT '个性签名',
  `address`        VARCHAR(200) NOT NULL COMMENT '默认收货地址',
  `is_deleted`     TINYINT      NOT NULL DEFAULT 0 COMMENT '注销标识（逻辑删除）',
  `locked_flag`    TINYINT      NOT NULL DEFAULT 0 COMMENT '锁定标识',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
  `update_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uk_user_login_name` (`login_name`),
  CONSTRAINT `chk_user_member` CHECK (`member_level` IN (1,2,3)),
  CONSTRAINT `chk_user_flags`  CHECK (`is_deleted` IN (0,1) AND `locked_flag` IN (0,1))
) ENGINE=InnoDB COMMENT='商城用户表：前台注册顾客账号与基础信息';

-- 2 后台管理员（实体）
CREATE TABLE `tb_flower_admin_user` (
  `admin_user_id`   INT         NOT NULL AUTO_INCREMENT COMMENT '管理员主键',
  `login_user_name` VARCHAR(50) NOT NULL COMMENT '登录名',
  `login_password`  CHAR(32)    NOT NULL COMMENT '密码摘要',
  `nick_name`       VARCHAR(50) NOT NULL COMMENT '显示昵称',
  `locked`          TINYINT     NOT NULL DEFAULT 0 COMMENT '锁定标识',
  `create_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`admin_user_id`),
  UNIQUE KEY `uk_admin_login_name` (`login_user_name`),
  CONSTRAINT `chk_admin_lock` CHECK (`locked` IN (0,1))
) ENGINE=InnoDB COMMENT='后台管理员表：全权管理商品/订单/会员';

-- 3 首页轮播图（实体，列名保持参考项目原样，仅换表名）
CREATE TABLE `tb_flower_carousel` (
  `carousel_id`   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '轮播主键',
  `carousel_url`  VARCHAR(300) NOT NULL COMMENT '轮播图URL',
  `redirect_url`  VARCHAR(200) NOT NULL DEFAULT '/' COMMENT '点击跳转地址',
  `carousel_rank` INT          NOT NULL DEFAULT 0 COMMENT '排序值（越大越靠前）',
  `is_deleted`    TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `create_user`   INT          NOT NULL DEFAULT 0 COMMENT '创建者id（0=系统）',
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `update_user`   INT          NOT NULL DEFAULT 0 COMMENT '更新者id（0=系统）',
  PRIMARY KEY (`carousel_id`)
) ENGINE=InnoDB COMMENT='首页轮播图表：运营位配置';

-- 4 首页内容配置（热销/新品/推荐/热词，列名保持参考项目原样）
CREATE TABLE `tb_flower_index_config` (
  `config_id`    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '配置项主键',
  `config_name`  VARCHAR(50)  NOT NULL DEFAULT '' COMMENT '显示文案（热搜词）',
  `config_type`  TINYINT      NOT NULL DEFAULT 3 COMMENT '槽位类型 1搜索框热搜 2下拉热词 3首页热销 4新品上线 5为你推荐',
  `goods_id`     BIGINT UNSIGNED NULL COMMENT '关联商品id',
  `redirect_url` VARCHAR(200) NULL DEFAULT NULL COMMENT '额外跳转地址',
  `config_rank`  INT          NOT NULL DEFAULT 0 COMMENT '排序值',
  `is_deleted`   TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除',
  `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `create_user`  INT          NOT NULL DEFAULT 0 COMMENT '创建者id（0=系统）',
  `update_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `update_user`  INT          NULL DEFAULT 0 COMMENT '更新者id（0=系统）',
  PRIMARY KEY (`config_id`),
  KEY `idx_config_type_goods` (`config_type`,`goods_id`),
  CONSTRAINT `chk_config_type` CHECK (`config_type` IN (1,2,3,4,5))
) ENGINE=InnoDB COMMENT='首页内容配置表：热搜词与首页商品位配置';

-- 5 商品分类（实体；三级结构。约定：一级 parent_id=0，程序与种子数据均用0，
--   层级-父子配对规则由触发器 trg_category_parent_* 强制校验（0不是合法外键值，
--   故此处不用自关联外键，是代码高重合与数据严谨性的工程取舍，见报告））
CREATE TABLE `tb_flower_category` (
  `category_id`    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类主键',
  `category_name`  VARCHAR(50) NOT NULL COMMENT '分类名称',
  `category_level` TINYINT     NOT NULL COMMENT '层级 1/2/3',
  `parent_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '父分类id（一级分类为0）',
  `category_rank`  INT         NOT NULL DEFAULT 0 COMMENT '同级排序值',
  `is_deleted`     TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除',
  `create_time`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`category_id`),
  KEY `idx_category_parent` (`parent_id`),
  CONSTRAINT `chk_category_level` CHECK (`category_level` IN (1,2,3))
) ENGINE=InnoDB COMMENT='商品分类表：三级类目树（鲜花/永生花/绿植/周边）';

-- 6 鲜花商品（核心实体）
CREATE TABLE `tb_flower_goods` (
  `goods_id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品主键',
  `goods_name`          VARCHAR(100) NOT NULL COMMENT '商品名称',
  `goods_intro`         VARCHAR(200) NOT NULL COMMENT '简介',
  `goods_category_id`   BIGINT UNSIGNED NOT NULL COMMENT '所属三级分类',
  `flower_material`     VARCHAR(100) NOT NULL DEFAULT '' COMMENT '主花材',
  `flower_color`        VARCHAR(50)  NOT NULL DEFAULT '' COMMENT '主色调',
  `flower_form`         TINYINT      NOT NULL DEFAULT 1 COMMENT '形态 1花束 2花盒 3盆栽 4单枝/散花',
  `shelf_life_days`     SMALLINT     NOT NULL DEFAULT 7 COMMENT '保质期（天）：鲜切花为保鲜期，盆栽按1年上限记',
  `original_price`      INT          NOT NULL DEFAULT 0 COMMENT '原价（分）',
  `selling_price`       INT          NOT NULL DEFAULT 0 COMMENT '售价（分）',
  `stock_num`           INT          NOT NULL DEFAULT 0 COMMENT '库存（CHECK保证非负，防超卖底线）',
  `safe_stock_num`      INT          NOT NULL DEFAULT 50 COMMENT '备货预警线（低于则出现在低库存视图）',
  `tag`                 VARCHAR(20)  NOT NULL DEFAULT '' COMMENT '营销标签',
  `goods_sell_status`   TINYINT      NOT NULL DEFAULT 1 COMMENT '上架状态 0下架 1上架',
  `goods_cover_img`     VARCHAR(300) NOT NULL DEFAULT '/admin/dist/img/no-img.png' COMMENT '主图',
  `goods_carousel`      VARCHAR(500) NOT NULL DEFAULT '/admin/dist/img/no-img.png' COMMENT '详情图',
  `goods_detail_content` TEXT        NULL COMMENT '图文详情',
  `is_deleted`          TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除',
  `create_time`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上架时间',
  `create_user`         INT          NOT NULL DEFAULT 0 COMMENT '添加者id（0=系统）',
  `update_time`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `update_user`         INT          NOT NULL DEFAULT 0 COMMENT '更新者id（0=系统）',
  PRIMARY KEY (`goods_id`),
  KEY `idx_goods_category` (`goods_category_id`),
  KEY `idx_goods_sell` (`goods_sell_status`,`is_deleted`),
  CONSTRAINT `fk_goods_category` FOREIGN KEY (`goods_category_id`)
    REFERENCES `tb_flower_category` (`category_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_goods_price` CHECK (`selling_price` > 0 AND `original_price` >= 0),
  CONSTRAINT `chk_goods_stock` CHECK (`stock_num` >= 0),
  CONSTRAINT `chk_goods_safe`  CHECK (`safe_stock_num` >= 0),
  CONSTRAINT `chk_goods_shelf` CHECK (`shelf_life_days` BETWEEN 1 AND 365),
  CONSTRAINT `chk_goods_form`  CHECK (`flower_form` IN (1,2,3,4)),
  CONSTRAINT `chk_goods_sell`  CHECK (`goods_sell_status` IN (0,1))
) ENGINE=InnoDB COMMENT='鲜花商品表：含花材/色调/形态/保质期等鲜花属性与备货预警线';

-- 7 购物车项（联系：user×goods 多对多）
CREATE TABLE `tb_flower_cart_item` (
  `cart_item_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '购物项主键',
  `user_id`      BIGINT UNSIGNED NOT NULL COMMENT '所属用户',
  `goods_id`     BIGINT UNSIGNED NOT NULL COMMENT '加购商品',
  `goods_count`  INT         NOT NULL DEFAULT 1 COMMENT '数量（1~5）',
  `is_deleted`   TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除（移出购物车）',
  `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入时间',
  `update_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`cart_item_id`),
  KEY `idx_cart_user` (`user_id`),
  CONSTRAINT `fk_cart_user`  FOREIGN KEY (`user_id`)
    REFERENCES `tb_flower_user` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_cart_goods` FOREIGN KEY (`goods_id`)
    REFERENCES `tb_flower_goods` (`goods_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_cart_count` CHECK (`goods_count` BETWEEN 1 AND 5)
) ENGINE=InnoDB COMMENT='购物车项表：用户与商品多对多的联系表';

-- 8 订单主表（核心实体；状态机）
CREATE TABLE `tb_flower_order` (
  `order_id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单主键',
  `order_no`           VARCHAR(20)  NOT NULL COMMENT '业务订单号（唯一）',
  `user_id`            BIGINT UNSIGNED NOT NULL COMMENT '下单用户',
  `total_price`        INT          NOT NULL DEFAULT 0 COMMENT '订单总价（分）',
  `pay_status`         TINYINT      NOT NULL DEFAULT 0 COMMENT '支付状态 0未支付 1支付成功 -1支付失败',
  `pay_type`           TINYINT      NOT NULL DEFAULT 0 COMMENT '支付方式 0无 1支付宝 2微信（模拟支付）',
  `pay_time`           DATETIME     NULL COMMENT '支付时间',
  `order_status`       TINYINT      NOT NULL DEFAULT 0 COMMENT '订单状态 0待支付 1已支付 2配货完成 3出库成功 4交易成功 -1手动关闭 -2超时关闭 -3商家关闭',
  `user_name`          VARCHAR(30)  NOT NULL DEFAULT '' COMMENT '收花人姓名（下单快照）',
  `user_phone`         VARCHAR(20)  NOT NULL DEFAULT '' COMMENT '收花人电话（快照）',
  `user_address`       VARCHAR(200) NOT NULL DEFAULT '' COMMENT '收花地址（快照）',
  `delivery_date`      DATE         NULL COMMENT '期望送达日期（鲜花礼赠场景）',
  `delivery_time_slot` TINYINT      NULL COMMENT '期望时段 1上午 2下午 3全天',
  `card_message`       VARCHAR(200) NULL COMMENT '贺卡留言',
  `extra_info`         VARCHAR(100) NOT NULL DEFAULT '' COMMENT '扩展信息',
  `is_deleted`         TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除',
  `create_time`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下单时间',
  `update_time`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`order_id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_order_user_status` (`user_id`,`order_status`),
  CONSTRAINT `fk_order_user` FOREIGN KEY (`user_id`)
    REFERENCES `tb_flower_user` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_order_price` CHECK (`total_price` >= 0),
  CONSTRAINT `chk_order_pay_status` CHECK (`pay_status` IN (-1,0,1)),
  CONSTRAINT `chk_order_pay_type`   CHECK (`pay_type` IN (0,1,2)),
  CONSTRAINT `chk_order_status`     CHECK (`order_status` IN (-3,-2,-1,0,1,2,3,4)),
  CONSTRAINT `chk_order_slot`       CHECK (`delivery_time_slot` IN (1,2,3))
) ENGINE=InnoDB COMMENT='订单主表：订单流转状态机；收花人信息为下单时点快照（反范式取舍点）';

-- 9 订单项（联系：order×goods；快照=有意反范式）
CREATE TABLE `tb_flower_order_item` (
  `order_item_id`   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单项主键',
  `order_id`        BIGINT UNSIGNED NOT NULL COMMENT '所属订单',
  `goods_id`        BIGINT UNSIGNED NOT NULL COMMENT '商品id（可统计单品销量）',
  `goods_name`      VARCHAR(100) NOT NULL COMMENT '下单时商品名（快照）',
  `flower_material` VARCHAR(100) NOT NULL DEFAULT '' COMMENT '下单时主花材（快照）',
  `goods_cover_img` VARCHAR(300) NOT NULL DEFAULT '/admin/dist/img/no-img.png' COMMENT '下单时主图（快照）',
  `selling_price`   INT          NOT NULL DEFAULT 0 COMMENT '下单时单价（分，快照）',
  `goods_count`     INT          NOT NULL DEFAULT 1 COMMENT '购买数量',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`order_item_id`),
  KEY `idx_item_order` (`order_id`),
  CONSTRAINT `fk_item_order` FOREIGN KEY (`order_id`)
    REFERENCES `tb_flower_order` (`order_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_item_goods` FOREIGN KEY (`goods_id`)
    REFERENCES `tb_flower_goods` (`goods_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_item_price` CHECK (`selling_price` >= 0),
  CONSTRAINT `chk_item_count` CHECK (`goods_count` BETWEEN 1 AND 99)
) ENGINE=InnoDB COMMENT='订单项表：订单与商品的联系表；快照防止商品改名改价污染历史订单';

-- 10 用户行为日志（【性能测试专用表】，目标≥100万行，无外键：写多读少的刻意设计）
CREATE TABLE `tb_flower_user_behavior_log` (
  `log_id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '日志主键',
  `user_id`        BIGINT UNSIGNED NOT NULL COMMENT '用户id（不设外键，写吞吐优先）',
  `goods_id`       BIGINT UNSIGNED NULL COMMENT '相关商品id',
  `behavior_type`  TINYINT     NOT NULL COMMENT '行为类型 1浏览 2搜索 3加购 4收藏',
  `search_keyword` VARCHAR(64) NULL COMMENT '搜索关键词（type=2时填）',
  `behavior_time`  DATETIME    NOT NULL COMMENT '行为时间',
  PRIMARY KEY (`log_id`),
  CONSTRAINT `chk_behavior_type` CHECK (`behavior_type` IN (1,2,3,4))
) ENGINE=InnoDB COMMENT='用户行为日志表（性能测试专用）：百万级数据支撑索引优化与执行计划对比实验';
-- ============================================================
-- 种子数据（极简版）：分类树 + 鲜花商品 + 用户/管理员 + 演示订单 + 运营位
-- 先执行 01_schema.sql。密码统一 123456 的 MD5。
-- 自检：订单总价与明细加总必须一致（返回0行=通过）。
-- ============================================================
USE flower_mall_db;

-- 一、分类树（三级）
INSERT INTO `tb_flower_category` (`category_id`,`category_name`,`category_level`,`parent_id`) VALUES
(1 ,'鲜花',      1, 0),
(2 ,'永生花·干花', 1, 0),
(3 ,'绿植·盆栽',  1, 0),
(4 ,'花艺周边',   1, 0),
(11,'玫瑰花束',   2, 1),
(12,'百合花束',   2, 1),
(13,'向日葵',     2, 1),
(14,'混搭定制花束', 2, 1),
(15,'永生花盒',   2, 2),
(16,'干花花束',   2, 2),
(17,'观叶绿植',   2, 3),
(18,'多肉植物',   2, 3),
(19,'花瓶花器',   2, 4),
(20,'花艺工具',   2, 4),
(21,'红玫瑰系列',  3, 11),
(22,'粉玫瑰系列',  3, 11),
(23,'香槟玫瑰系列', 3, 11),
(24,'香水百合',   3, 12),
(25,'亚洲百合',   3, 12),
(26,'向日葵花束',  3, 13),
(27,'节日订制花束', 3, 14),
(28,'日常轻花束',  3, 14),
(29,'方形永生花盒', 3, 15),
(30,'心形永生花盒', 3, 15),
(31,'满天星干花',  3, 16),
(32,'龟背竹',     3, 17),
(33,'琴叶榕',     3, 17),
(34,'多肉拼盆',   3, 18),
(35,'玻璃花瓶',   3, 19),
(36,'陶瓷花瓶',   3, 19),
(37,'花艺剪刀',   3, 20),
(38,'包装耗材',   3, 20);

-- 二、鲜花商品（价格=分；预留3个低于备货线的商品演示低库存视图）
INSERT INTO `tb_flower_goods`
(`goods_id`,`goods_name`,`goods_intro`,`goods_category_id`,`flower_material`,`flower_color`,`flower_form`,`shelf_life_days`,`original_price`,`selling_price`,`stock_num`,`safe_stock_num`,`tag`,`goods_sell_status`,`goods_detail_content`) VALUES
(1001,'告白玫瑰·红玫瑰花束33枝','经典33枝红玫瑰，尤加利叶点缀',21,'红玫瑰+尤加利','正红',1,7,15800,12900,23,50,'热销',1,'<p>33枝等级红玫瑰，牛皮纸暖色包装。</p>'),
(1002,'挚爱长情·99枝红玫瑰花束','求婚首选99枝红玫瑰',21,'红玫瑰','正红',1,7,69900,59900,60,40,'爆品',1,'<p>99枝红玫瑰，心形摆配。</p>'),
(1003,'初恋粉玫瑰花束19枝','19枝粉玫瑰，少女感首选',22,'粉玫瑰','粉色',1,7,13900,9900,88,50,'上新',1,'<p>19枝戴安娜粉玫瑰。</p>'),
(1004,'粉玫瑰香槟混搭33枝','粉调与香槟的温柔组合',22,'粉玫瑰+香槟玫瑰','粉调',1,7,18900,15800,75,50,'日常',1,'<p>雾面纸包装。</p>'),
(1005,'香槟本色玫瑰花束33枝','奶香调香槟玫瑰，高级感',23,'香槟玫瑰','香槟色',1,7,15800,13200,8,60,'热销',1,'<p>33枝香槟玫瑰，丝绒缎带。</p>'),
(1006,'香槟玫瑰尤加利花束21枝','21枝中小体量，日常首选',23,'香槟玫瑰+尤加利','香槟色',1,7,11900,9600,64,50,'日常',1,'<p>21枝香槟玫瑰。</p>'),
(1007,'多语花香百合花束6枝','6枝香水百合，清香持久',24,'香水百合','白粉',1,10,16900,13900,50,40,'上新',1,'<p>客厅插花首选。</p>'),
(1008,'百合混搭花束9枝','9枝含苞百合',24,'香水百合+多头百合','白调',1,10,19900,16900,42,40,'日常',1,'<p>婚庆常用。</p>'),
(1009,'亚洲百合家庭花束8枝','轻度花香，办公友好',25,'亚洲百合','橙黄',1,8,10900,8900,70,40,'日常',1,'<p>橙黄键暖光。</p>'),
(1010,'元气向日葵花束6枝','6枝向日葵，毕业谢师首选',26,'向日葵+尤加利','明黄',1,6,12900,10600,35,40,'热销',1,'<p>向日葵配尤加利棉花。</p>'),
(1011,'向阳而生向日葵3枝','3枝小体量，桌面治愈',26,'向日葵','明黄',1,6,6900,5600,80,50,'日常',1,'<p>迷你花纸包装。</p>'),
(1012,'七夕限定·红粉玫瑰大花束','节日订制大花束，含贺卡',27,'红玫瑰+粉玫瑰','红粉',1,5,26800,23800,12,60,'节日限定',1,'<p>红粉双拼52枝。</p>'),
(1013,'生日快乐混搭花束','车厘子色混搭，送闺蜜',27,'玫瑰+洋桔梗+雏菊','多色',1,6,14800,11800,66,50,'热销',1,'<p>车厘子红配奶油白。</p>'),
(1014,'办公桌面轻花束','小体量混搭不占地',28,'玫瑰+雏菊','多色',1,6,6900,5900,90,50,'日常',1,'<p>适合送同事。</p>'),
(1015,'白绿系日常混搭花束','清新系混搭，文艺满格',28,'玫瑰+洋甘菊+满天星','白绿调',1,6,9900,7900,72,50,'上新',1,'<p>棉麻丝带。</p>'),
(1016,'星空方形永生花盒','进口永生玫瑰，星空蓝染制',29,'永生玫瑰','蓝黑紫',2,365,32900,29900,26,20,'高级感',1,'<p>含灯带。</p>'),
(1017,'挚爱心形永生花盒','心形永生花礼盒',30,'永生玫瑰','经典红',2,365,35900,32900,18,15,'高级感',1,'<p>纪念日首选。</p>'),
(1018,'云雾满天星干花束','自然风干不褪色',31,'满天星','奶白',2,180,8900,6900,96,40,'上新',1,'<p>奶白基调。</p>'),
(1019,'龟背竹盆栽·净化空气','INS风客厅标配',32,'龟背竹','绿',3,365,13900,11900,45,30,'热销',1,'<p>高约70cm。</p>'),
(1020,'琴叶榕大苗·北欧风','大叶琴叶榕',33,'琴叶榕','绿',3,365,25900,21900,22,20,'高级感',1,'<p>高约120cm。</p>'),
(1021,'治愈多肉拼盆','多肉组合盆，桌面治愈',34,'多肉组合','多色',3,365,8900,6900,5,30,'新手友好',1,'<p>3-5头组合。</p>'),
(1022,'几何玻璃花瓶','北欧几何线条',35,'玻璃器皿','透明',4,365,9900,7900,110,50,'日常',1,'<p>手工玻璃。</p>'),
(1023,'奶油白陶瓷花瓶','哑光釉面，温润耐看',36,'陶瓷','奶白',4,365,11900,9600,85,50,'上新',1,'<p>适合长枝百合。</p>'),
(1024,'专业花艺剪','减力柄，练习必备',37,'不锈钢','银黑',4,365,6900,4900,120,60,'工具',1,'<p>含保护套。</p>'),
(1025,'牛皮纸包装纸10张','花束包装耗材',38,'牛皮纸','牛皮色',4,365,2900,1900,200,80,'工具',1,'<p>58×78cm。</p>');

-- 三、用户与管理员
INSERT INTO `tb_flower_user` (`user_id`,`nick_name`,`login_name`,`password_md5`,`phone`,`member_level`,`introduce_sign`,`address`) VALUES
(1,'花间客小满','13800001111','e10adc3949ba59abbe56e057f20f883e','13800001111',3,'爱花之人','杭州市西湖区文三路100号 苏晚晚 13800001111'),
(2,'南风知我意','13900002222','e10adc3949ba59abbe56e057f20f883e','13900002222',2,'送花给跳舞的她','杭州市滨江区江南大道200号 陆南风 13900002222'),
(3,'桃桃乌龙','13700003333','e10adc3949ba59abbe56e057f20f883e','13700003333',1,'办公室也要有花','绍兴市越城区胜利路66号 桃桃 13700003333');

INSERT INTO `tb_flower_admin_user` (`admin_user_id`,`login_user_name`,`login_password`,`nick_name`) VALUES
(1,'admin','e10adc3949ba59abbe56e057f20f883e','花集超管');

-- 四、演示订单（A已支付 vending时钟固定 / B待支付=超时关单演示素材 / C刚下待支付=未被关掉反例）
-- 注意：三笔订单的明细加总都等于total_price（自检在文末）
INSERT INTO `tb_flower_order`
(`order_id`,`order_no`,`user_id`,`total_price`,`pay_status`,`pay_type`,`pay_time`,`order_status`,`user_name`,`user_phone`,`user_address`,`delivery_date`,`delivery_time_slot`,`card_message`,`extra_info`,`create_time`) VALUES
(1,'20250920000112345',1,26800,1,2,'2025-09-20 12:30:00',1,'苏晚晚','13800001111','杭州市西湖区文三路100号 苏晚晚 13800001111','2025-09-21',1,'生日快乐，天天开心！','','2025-09-20 12:20:00'),
(2,'20250926000154321',2,1238400,0,0,NULL,0,'陆南风','13900002222','杭州市滨江区江南大道200号 陆南风 13900002222','2025-10-01',3,'新婚快乐，百年好合！','婚庆团体订购（96束红玫瑰）','2025-09-26 09:10:00');

INSERT INTO `tb_flower_order_item` (`order_id`,`goods_id`,`goods_name`,`flower_material`,`goods_cover_img`,`selling_price`,`goods_count`) VALUES
(1,1001,'告白玫瑰·红玫瑰花束33枝','红玫瑰+尤加利','/admin/dist/img/no-img.png',12900,1),
(1,1007,'多语花香百合花束6枝','香水百合','/admin/dist/img/no-img.png',13900,1),
(2,1001,'告白玫瑰·红玫瑰花束33枝','红玫瑰+尤加利','/admin/dist/img/no-img.png',12900,96);

-- 五、运营位
INSERT INTO `tb_flower_index_config` (`config_name`,`config_type`,`goods_id`,`config_rank`) VALUES
('红玫瑰花束',1,NULL,300),
('向日葵花束',1,NULL,200),
('生日混搭花束',1,NULL,100),
('热销 告白玫瑰33枝',3,1001,300),
('热销 元气向日葵',3,1010,200),
('新品 星空永生花盒',4,1016,300),
('推荐 生日快乐混搭',5,1013,300);

-- 首页轮播图位占位（演示前可替换为鲜花Banner图）
INSERT INTO `tb_flower_carousel` (`carousel_url`,`redirect_url`,`carousel_rank`,`create_user`) VALUES
('/admin/dist/img/no-img.png','/goods-list?categoryId=11',300,1),
('/admin/dist/img/no-img.png','/goods-list?categoryId=15',200,1);

-- 六、自检：订单总价 vs 明细加总（0行=通过）
SELECT o.order_no, o.total_price, SUM(oi.selling_price*oi.goods_count) AS items_sum
FROM tb_flower_order o JOIN tb_flower_order_item oi ON oi.order_id=o.order_id
GROUP BY o.order_id, o.order_no, o.total_price
HAVING o.total_price <> SUM(oi.selling_price*oi.goods_count);
