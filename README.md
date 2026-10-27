# 花漾集商城 · 应用工程（课程设计交付件）

线上鲜花商城订单管理系统——数据层为基于鲜花业务的自主设计，应用骨架参考开源电商项目（声明见报告§12）。

## 快速启动
```bash
# 前置：执行 sql/01~06 脚本建库（flower_mall_db）
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home
mvn -DskipTests spring-boot:run     # 端口 28090
```
- 前台：http://localhost:28090 （测试账号 13800001111 / 123456）
- 后台：http://localhost:28090/admin/login （admin / 123456，演示为模拟支付+验证码）
- 数据库账号：flower_app（最小权限，见 sql/06_security.sql）

## 与参考骨架的差异（对接三件事，均可在文件内 grep 验证）
1. mapper 表名 tb_flower_* + 订单项"花材快照"子查询（resources/mapper/）
2. 数据源指向 flower_mall_db + flower_app（application.properties）
3. 品牌文案"花漾集"（templates/）

## 参考文档（docs/）
- 参考_newbee原版README.md / 参考_newbee架构地图.md —— 骨架出处与分层说明
- API.md / DEVELOPMENT.md / FAQ.md —— 开源项目原生文档
