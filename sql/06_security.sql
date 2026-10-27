-- ============================================================
-- 数据库安全设计：三个角色账号 + 最小权限
-- 依赖：01~05 已执行
-- 设计思路（答辩话术）：
--   1. 最小权限原则：按"角色需要什么"发权限，不按"方便"发权限；
--   2. 应用账号不下放 DELETE：全库删除均为逻辑删除（is_deleted=1），
--      物理删除不属于业务行为，权限上直接收走即可杜绝误删/恶意删；
--   3. 运营查询只读：报表/后台看数账号只给 SELECT，改库必须走应用账号；
--   4. DBA 全权：日常不用于业务，只在结构变更/维护时登入；
--   5. 应用层还有登录拦截器+管理员校验 => "应用层 + 数据库层"双层防御。
-- 注意：本脚本含 DROP USER IF EXISTS，可重复执行。
--   密码为演示用强密码示例，验收展示可现场 SHOW GRANTS 佐证。
-- ============================================================
USE mysql;

DROP USER IF EXISTS 'flower_app'@'localhost';
DROP USER IF EXISTS 'flower_report'@'localhost';
DROP USER IF EXISTS 'flower_admin'@'localhost';

-- 应用账号：Spring Boot dataSource 使用的账号（业务读写+执行存储过程）
CREATE USER 'flower_app'@'localhost' IDENTIFIED BY 'F1ower#App2026';
GRANT SELECT, INSERT, UPDATE, EXECUTE ON flower_mall_db.* TO 'flower_app'@'localhost';

-- 运营查询账号：只读（报表/看数）
CREATE USER 'flower_report'@'localhost' IDENTIFIED BY 'F1ower#Ro2026';
GRANT SELECT ON flower_mall_db.* TO 'flower_report'@'localhost';

-- DBA 账号：结构变更与维护（日常不用）
CREATE USER 'flower_admin'@'localhost' IDENTIFIED BY 'F1ower#Dba2026';
GRANT ALL PRIVILEGES ON flower_mall_db.* TO 'flower_admin'@'localhost';

FLUSH PRIVILEGES;
