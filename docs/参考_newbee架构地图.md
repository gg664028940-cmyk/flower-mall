# newbee-mall 架构地图（AI 协作专用文档）

> **这份文档的用途**：让 AI（或新人）在不通读源码的情况下，几分钟内建立对整个项目的准确认知。
> AI 新会话时只需读本文件 + 按需查阅"关键文件索引"，即可高质量回答问题、改代码。
> 最后更新：2026-09-09（基于初始学习版本源码实测生成）

---

## 1. 项目一句话总览

**newbee-mall（初始版本）**：一个基于 **Spring Boot 2.7.5 + Thymeleaf** 的服务端渲染式电商系统（非前后端分离），包含前台商城（逛/搜/买）与后台管理（进货/发货）两套界面，共用同一个 Spring Boot 进程。

- 技术栈：Java 8、Spring Boot 2.7.5（Web + Thymeleaf）、MyBatis 2.2.2（XML 写 SQL）、MySQL、Hutool（验证码）、spring-session（Session 登录态）
- 无 Redis、无消息队列、无微服务，**所有状态放 Session，所有数据放 MySQL**——这是它适合学习的原因
- 代码规模：88 个 Java 文件 / 约 7,600 行；9 张业务表

---

## 2. 本地运行清单（macOS）

1. **JDK**：安装 JDK 8 或 11（pom 按 Java 8 编译；装了 17+ 可能报 `javax.*` 相关错误）。推荐用 SDKMAN 或 Homebrew 装_temurin@8/11_。
2. **MySQL**：5.7 或 8.0。执行 `src/main/resources/newbee_mall_schema.sql`（自动建库 `newbee_mall_db` 并插入演示数据，含商品/分类/轮播）。
3. **改配置** `src/main/resources/application.properties`：
   - 第 10~12 行：MySQL 地址/账号/密码（默认 `root`/`123456`）
   - 端口固定 `28089`（想改就改 `server.port`）
4. **必改的坑**：`common/Constants.java:20` 的上传目录是 **Windows 路径 `"D:\\upload\\"`**，mac 上必须改成如 `"/Users/Zhuanz/upload/"` 并手动 `mkdir -p` 该目录。该目录同时映射为 `/upload/**` 和 `/goods-img/**` 两个 URL。
5. **商品图片**：SQL 里的商品图路径形如 `/goods-img/xxx.jpg`，需要把作者提供的图片包解压到上面那个目录，否则首页图裂（见 `docs/FAQ.md`）。
6. **构建**：仓库无 Maven Wrapper，需本机装 Maven（或在 IDEA 中打开直接跑 `NewBeeMallApplication`）。
7. **访问入口**：
   - 前台商城：`http://localhost:28089/`（注册新用户即可逛）
   - 后台管理：`http://localhost:28089/admin/login`，默认账号 `admin` / `123456`（MD5 存于 `tb_newbee_mall_admin_user`）
8. 验证码登录、图片上传等功能依赖 Hutool 与磁盘目录，报错先查上传目录是否可写。

---

## 3. 分层架构与一次请求的生命周期

```
浏览器
  │  HTTP
  ▼
Interceptor（3 个拦截器，登录/购物车数量）
  ▼
Controller（admin/* 后台、mall/* 前台、common/* 公共）
  │  组装参数、调 Service、往 request/session 塞数据
  ▼
Service / ServiceImpl（业务逻辑、@Transactional 事务）
  │  entity ↔ VO 转换（BeanUtil.copyProperties）
  ▼
DAO（XxxMapper 接口，@MapperScan 自动扫描）
  ▼
resources/mapper/XxxMapper.xml（手写 SQL）→ MySQL
  │
  ▼
返回视图名 → Thymeleaf 模板渲染（templates/mall|admin/*.html）
   或返回 JSON（util.Result 包装，用于后台的 AJAX 分页表格）
```

**两套返回风格并存**：
- 前台页面：`@Controller` 返回视图名字符串，数据放 `request.setAttribute(...)`
- 后台管理页：页面还是 Thymeleaf，但列表数据走 `@ResponseBody` + `Result` JSON（前端用 admin/dist 里的 JS 模板做分页表格）

---

## 4. 包结构地图

```
ltd.newbee.mall
├── NewBeeMallApplication      启动类，@MapperScan("ltd.newbee.mall.dao")
├── common/                    常量与枚举（见 §6 速查）
│   ├── Constants              全局常量：上传目录、首页数量、session key、购物车上限等
│   ├── ServiceResultEnum      Service 层通用返回文案（SUCCESS/DB_ERROR/...）
│   ├── NewBeeMallException    业务异常（fail() 静态抛出，全局处理器兜底）
│   ├── NewBeeMallOrderStatusEnum  订单状态机（见 §8）
│   └── IndexConfigTypeEnum / NewBeeMallCategoryLevelEnum / PayTypeEnum / PayStatusEnum
├── config/
│   └── NeeBeeMallWebMvcConfigurer  ★ 拦截器注册规则 + 静态资源映射（上传目录）
├── controller/
│   ├── admin/                 后台 6 个管理页 Controller（登录/轮播/分类/商品/首页配置/订单/用户）
│   ├── mall/                  前台 5 个 Controller（首页/商品/购物车/订单/个人中心）
│   ├── common/                全局异常处理、错误页、登录验证码、图片上传
│   └── vo/                    视图对象（给页面用的 DTO，约 15 个）
├── dao/                       9 个 Mapper 接口（无注解 SQL，全走 XML）
├── entity/                    9 个数据库表实体（与表一一对应）
├── interceptor/               3 个拦截器（见 §6）
├── service/ + service/impl/   8 组业务接口/实现
└── util/                      Result、PageResult、PageQueryUtil、BeanUtil、MD5Util、NumberUtil 等
```

**entity vs VO 约定**：`entity` = 表字段原样；`controller/vo` = 页面展示用的加工对象（多出状态中文、订单项列表等字段）。转换统一用 `util/BeanUtil.copyProperties / copyList`。

**Mapper 命名规律**：DAO 接口 `XxxMapper.java` ↔ XML `resources/mapper/XxxMapper.xml`，XML 内 id 与接口方法名一一对应。

---

## 5. 数据库模型（9 张表）

```
tb_newbee_mall_user             商城用户（前台注册，MD5 密码）
tb_newbee_mall_admin_user       后台管理员（默认 admin/123456）
tb_newbee_mall_goods_info       商品（含原价/售价/库存/上下架状态/分类外键）
tb_newbee_mall_goods_category   分类（三级结构：level 1/2/3，parent_id 自关联）
tb_newbee_mall_carousel         首页轮播图
tb_newbee_mall_index_config     首页配置项（type: 热卖/新品/推荐，搜索页也用它）
tb_newbee_mall_shopping_cart_item  购物车项（user_id + goods_id + 数量）
tb_newbee_mall_order            订单主表（订单号/总价/状态机字段/支付方式）
tb_newbee_mall_order_item       订单项快照（下单时把商品名/价/图复制进来，防商品后续改动）
```

关系：`user 1—N cart_item N—1 goods`；`user 1—N order 1—N order_item`；`goods N—1 category(三级)`。删除是**逻辑删除**（`is_deleted` 字段）。

---

## 6. 核心机制速查（改代码前必读）

**① Session 里的三种登录态**
| key | 存的是 | 写入位置 |
|---|---|---|
| `newBeeMallUser` (Constants.MALL_USER_SESSION_KEY) | NewBeeMallUserVO（含购物车数量） | 前台登录/注册 |
| `loginUser` / `loginUserId` | 管理员昵称/ID | 后台登录 AdminController |
| `mallVerifyCode` | 登录验证码答案 | CommonController |

**② 三个拦截器的拦截范围**（定义于 `config/NeeBeeMallWebMvcConfigurer`）
| 拦截器 | 规则 |
|---|---|
| AdminLoginInterceptor | 拦 `/admin/**`，放行 `/admin/login`、静态资源 |
| NewBeeMallLoginInterceptor | 只拦前台敏感路径白名单：`/goods/detail`、`/shop-cart*`、`/saveOrder`、`/orders*`、`/personal*`、支付页 |
| NewBeeMallCartNumberInterceptor | 拦除后台/登录注册外的所有请求，每次刷新 session 中购物车数量（所以每次请求多一次 DB 查询） |

**③ 统一返回与异常**
- `util.Result<T>`：`resultCode(200成功/500失败) + message + data`
- `util.PageResult`：后台表格分页 JSON（`list + totalCount + currPage + pageSize`）
- `util.PageQueryUtil`：吸收 `page/limit` 请求参数并算出 `start`，直接传给 MyBatis XML 里 `LIMIT #{start},#{limit}`
- Service 层习惯返回 `String`（`ServiceResultEnum` 文案）而非布尔；失败用 `NewBeeMallException.fail("...")` 抛出，由 `controller/common/NewBeeMallExceptionHandler` 统一处理

**④ 业务常量**都在 `Constants`：首页轮播 5 张、一级分类 10 个、购物车最多 13 件、单商品最多买 5 件、搜索每页 10 条、我的订单每页 3 条。

---

## 7. 关键业务链路

**下单主链路（最重要，`NewBeeMallOrderServiceImpl.saveOrder`，一个 @Transactional 内完成）**：
1. 按购物车项查商品 → 校验**下架**商品 → 校验**库存**不足
2. 删购物车项 → 扣库存（`updateStockNum`）
3. 生成订单号 `NumberUtil.genOrderNo()`，累加总价（售价 × 数量）
4. 插入 `order` 主表（useGeneratedKeys 回填 orderId）→ 批量插入 `order_item` 快照
5. 任一步失败抛异常整体回滚；成功返回订单号，Controller 跳转支付选择页
6. 支付是**模拟的**（`alipay.html`/`wxpay.html` 页面按钮触发 `paySuccess` 改状态），没接真实第三方支付

**订单状态机（NewBeeMallOrderStatusEnum）**：
```
0 待支付 ──paySuccess──> 1 已支付 ──checkDone(后台配货)──> 2 配货完成
        ──checkOut(后台出库)──> 3 出库成功 ──finishOrder(用户确认)──> 4 交易成功
任意状态(0~3) ──closeOrder/cancelOrder──> -1 手动关闭 / -2 超时关闭 / -3 商家关闭（并回滚库存 recoverStockNum）
```
后台改单只允许状态 0~2；`checkDone` 要求状态=1；`checkOut` 要求 1 或 2；确认收货要求=3。

**其他链路**：首页 = 分类树 + 轮播 + 三组 IndexConfig 商品；搜索 = 按三级分类或关键词（`GoodsController`）；后台商品/轮播/分类管理都是"列表分页 + AJAX 增删改"同一套模板套路，看懂 `NewBeeMallGoodsController` + 对应 service 即可举一反三。

---

## 8. URL 路由地图（主要）

| 前台 | 后台 |
|---|---|
| `/` `/index` 首页（IndexController） | `/admin/login` 登录 |
| `/search` 搜索（GoodsController） | `/admin/index` 数据面板 |
| `/goods/detail/{id}` 商品详情 | `/admin/carousels` 轮播管理 |
| `/shop-cart` 购物车（ShoppingCartController） | `/admin/categories` 分类管理 |
| `/saveOrder` 结算下单（OrderController） | `/admin/goods` 商品管理 |
| `/orders` 我的订单、`/orders/{orderNo}` 详情 | `/admin/indexConfigs` 首页配置 |
| `/selectPayType` `/payPage` 模拟支付 | `/admin/orders` 订单管理（配货/出库/关闭） |
| `/personal` 个人中心（PersonalController） | `/admin/users` 会员管理 |
| `/login` `/register` `/logout` | `/admin/profile` 改密码/昵称 |
| `/common/upload/image` 图片上传 | `/upload/xxx` 上传文件回显 |

---

## 9. 建议学习路径（由易到难）

1. **跑起来**：按 §2 清单，改上传路径 + 导 SQL + 启动
2. **首页链路**（最简单的一条竖切）：`IndexController` → `Carousel/IndexConfig/Category Service` → mapper XML → `templates/mall/index.html`
3. **登录与拦截器**：`PersonalController`（登录/注册）+ 3 个拦截器 + 验证码
4. **购物车**：`ShoppingCartController` ↔ `NewBeeMallShoppingCartServiceImpl`（含 13/5 上限校验）
5. **后台 CRUD 套路**：`NewBeeMallGoodsController`（分页 PageQueryUtil/PageResult + Result JSON）
6. **订单（压轴）**：状态机 §7 + `saveOrder` 事务 + 后台配货出库
7. 进阶改造练手：加"商品收藏"、把购物车数量从拦截器挪到 Redis、把 MD5 换 BCrypt 等

---

## 10. 关键文件索引（AI 按需精读）

| 要干什么 | 读这些（不必全项目扫） |
|---|---|
| 理解拦截/路由 | config/NeeBeeMallWebMvcConfigurer.java |
| 讲解下单/订单 | service/impl/NewBeeMallOrderServiceImpl.java、controller/mall/OrderController.java |
| 购物车 | controller/mall/ShoppingCartController.java、service/impl/NewBeeMallShoppingCartServiceImpl.java |
| 后台 CRUD 模板 | controller/admin/NewBeeMallGoodsController.java、resources/mapper/NewBeeMallGoodsMapper.xml |
| 表结构/初始数据 | resources/newbee_mall_schema.sql |
| 全局常量/枚举 | common/Constants.java、common/NewBeeMallOrderStatusEnum.java、common/ServiceResultEnum.java |
| 工具类 | util/ 下 Result、PageResult、PageQueryUtil、BeanUtil |
| 官方文档 | docs/API.md（接口文档）、docs/DEVELOPMENT.md、docs/FAQ.md |

## 11. AI 协作提示（新会话开场白模板）

```
请先阅读项目根目录的 ARCHITECTURE.md，然后基于它回答/编码，
只在需要细节时再精读第 10 节列出的对应文件，不要全项目扫描。
我的问题/任务是：……
```

> 维护提示：如果改动涉及架构（新增拦截器、改表、换技术栈），记得让 AI 同步更新本文件，保持"地图"不过期。
